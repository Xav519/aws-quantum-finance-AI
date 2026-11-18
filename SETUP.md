# Setup Guide: Deploy and Reproduce the Results

This guide takes you from an empty AWS account to a running copy of the system, and shows how to check that your deployment produces **the same results as the README**.

| | |
|---|---|
| **Time** | About 30 minutes (most of it is one-time account preparation and CloudFront propagation) |
| **Cost** | Near zero when idle. A few cents per quantum job, a fraction of a cent per AI summary ([details](#8-costs)) |
| **Region** | `us-east-1` (Braket SV1 and the `us.` Claude inference profile are available there) |

**Contents**

1. [Prerequisites](#1-prerequisites)
2. [One-time AWS account preparation](#2-one-time-aws-account-preparation)
3. [Run the tests locally (optional, 2 minutes)](#3-run-the-tests-locally-optional)
4. [Deploy](#4-deploy)
5. [Reproduce the results](#5-reproduce-the-results)
6. [See it working inside AWS](#6-see-it-working-inside-aws)
7. [Configuration](#7-configuration)
8. [Costs](#8-costs)
9. [Troubleshooting](#9-troubleshooting)
10. [Tear down](#10-tear-down)

---

## 1. Prerequisites

| Tool | Version | Check |
|---|---|---|
| AWS account | IAM user or role able to create IAM, Lambda, API Gateway, DynamoDB, S3, CloudFront, EventBridge, CloudWatch, SNS, Braket and Bedrock resources (e.g. `AdministratorAccess` in a sandbox account) | `aws sts get-caller-identity` |
| AWS CLI | v2 | `aws --version` |
| Terraform | ≥ 1.7 | `terraform version` |
| Git | any | `git --version` |
| Python | 3.12+ (only for local tests and the benchmark) | `python --version` |

Configure credentials for the CLI and Terraform, for example:

```bash
aws configure            # or: aws configure sso / export AWS_PROFILE=...
aws sts get-caller-identity
```

---

## 2. One-time AWS account preparation

These two steps cannot be done by Terraform and only need to be done once per account.

### 2.1 Enable Amazon Braket

1. Open the [Amazon Braket console](https://us-east-1.console.aws.amazon.com/braket/home?region=us-east-1) in **us-east-1**.
2. Go to **Permissions and settings** and accept the terms if prompted. Under **Service-linked role**, create the role if it does not exist.

Or from the CLI:

```bash
aws iam create-service-linked-role --aws-service-name braket.amazonaws.com
# "has been taken" means it already exists, which is fine
aws iam get-role --role-name AWSServiceRoleForAmazonBraket --query Role.Arn
```

### 2.2 Enable Claude Haiku 4.5 on Amazon Bedrock

1. Open the [Bedrock console](https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1) → **Model access** (or **Model catalog**).
2. Request access to **Anthropic Claude Haiku 4.5**. New accounts must fill in Anthropic's short use-case form first. Approval is usually immediate.

Verify access (bash):

```bash
aws bedrock-runtime invoke-model --region us-east-1 \
  --model-id us.anthropic.claude-haiku-4-5-20251001-v1:0 \
  --cli-binary-format raw-in-base64-out \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":20,"messages":[{"role":"user","content":"Reply with OK"}]}' \
  bedrock-test.json && cat bedrock-test.json
```

You should see a JSON response containing `"text": "OK"`. If Bedrock access is missing, the system still works: summaries fall back to a template and the API reports `"narrative_source": "fallback"`.

---

## 3. Run the tests locally (optional)

This checks the code and the quantum circuit before you spend anything on AWS.

```bash
git clone https://github.com/Xav519/aws-quantum-finance-AI.git
cd aws-quantum-finance-AI
python -m venv .venv
source .venv/bin/activate          # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
pytest
```

Expected: `48 passed`.

---

## 4. Deploy

### 4.1 Configure

```bash
cd rootTerraformCode
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
alert_email = "you@example.com"

# Required if you are not the original author: S3 bucket names are global,
# so the default prefix "quantum-finance" may already be taken.
project = "qf-yourname"
```

### 4.2 Apply

```bash
terraform init
terraform plan        # review: roughly 60 resources to create on a fresh account
terraform apply       # type "yes"
```

The apply takes 5-10 minutes; most of that is the CloudFront distribution. When it finishes, Terraform prints the outputs:

```
api_url                    = "https://abc123.execute-api.us-east-1.amazonaws.com/"
demo_url                   = "https://d1234example.cloudfront.net"
cloudfront_distribution_id = "E1234EXAMPLE"
dynamodb_table             = "qf-yourname-dev-jobs"
results_bucket             = "amazon-braket-qf-yourname-dev"
lambda_functions           = { braket = "...", classical = "...", get_job = "...", orchestrator = "..." }
...
```

Save the API URL for the next steps:

```bash
# bash
API=$(terraform output -raw api_url)
# PowerShell
$API = terraform output -raw api_url
```

### 4.3 Confirm the alert email

AWS sends a **"Subscription Confirmation"** email to `alert_email`. Click the link so alarms can reach you.

### 4.4 Upgrading an existing deployment of the previous version

If you deployed an earlier version of this repository, `terraform plan` will show:

- **moves** (not re-creations) for the Lambda log groups, the orchestrator alarm and `index.html`, thanks to `moved` blocks in `rootTerraformCode/main.tf`;
- four new per-function IAM roles replacing the two shared ones;
- a CloudFront distribution, a Lambda layer and new alarms being created;
- the S3 website configuration, the public bucket policy and the DynamoDB `braket-task-arn-index` being removed.

The frontend URL changes from the old S3 website address to the CloudFront `demo_url`.

---

## 5. Reproduce the results

All inputs below are in [`examples/`](examples/). The classical results are deterministic, so they must match exactly. The quantum metrics come from 1,000 random measurements, so they vary slightly per run within the ranges given.

> `POST /optimize` is rate-limited to 1 request per second (burst 5). Wait a moment between requests if you get a `429`.

### 5.1 In the browser

1. Open `demo_url`.
2. Select **3 Analysts · 3 Threats** and type the values from `examples/classical-3x3.json`:

   |                   | Ransomware | Data Exfiltration | Phishing Campaign |
   |-------------------|-----------:|------------------:|------------------:|
   | Sarah (Network)   | 72000      | 95000             | 98000             |
   | Marc (Phishing)   | 112000     | 31000             | 67000             |
   | David (Forensics) | 56000      | 65000             | 111000            |

3. Click **Find Optimal Assignment**. Expected within about 2 seconds:
   - **Total Financial Exposure: $185,000**
   - Greedy baseline **$214,000**, saved **$29,000**, assignments checked **6**
   - Sarah → Phishing Campaign, Marc → Data Exfiltration, David → Ransomware

4. Select **5 Analysts · 5 Threats**, enter the matrix from the README (or `examples/quantum-5x5.json`) and run it. A spinner shows the Braket job; after 1-2 minutes you should see the [expected quantum result](#53-quantum-path-5x5-on-amazon-braket).

### 5.2 Classical path (3×3) with the API

```bash
# bash
curl -s -X POST "${API}optimize" -H "Content-Type: application/json" \
  -d @../examples/classical-3x3.json | python -m json.tool
```

```powershell
# PowerShell
$body = Get-Content ..\examples\classical-3x3.json -Raw
Invoke-RestMethod -Method Post -Uri "${API}optimize" -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 5
```

Expected (exact; `job_id`, `created_at` and the summary wording will differ):

```json
{
  "status": "COMPLETE",
  "method": "CLASSICAL",
  "assignment": [
    {"analyst": "Sarah (Network)",   "alert": "Phishing Campaign", "cost": 98000},
    {"analyst": "Marc (Phishing)",   "alert": "Data Exfiltration", "cost": 31000},
    {"analyst": "David (Forensics)", "alert": "Ransomware",        "cost": 56000}
  ],
  "total_cost": 185000,
  "greedy_cost": 214000,
  "savings": 29000,
  "combinations_evaluated": 6,
  "narrative_source": "bedrock"
}
```

### 5.3 Quantum path (5×5) on Amazon Braket

Submit:

```bash
# bash
JOB=$(curl -s -X POST "${API}optimize" -H "Content-Type: application/json" \
  -d @../examples/quantum-5x5.json | python -c "import sys, json; print(json.load(sys.stdin)['job_id'])")
echo "$JOB"
```

```powershell
# PowerShell
$body = Get-Content ..\examples\quantum-5x5.json -Raw
$JOB = (Invoke-RestMethod -Method Post -Uri "${API}optimize" -ContentType "application/json" -Body $body).job_id
$JOB
```

The submit response is `202 Accepted` with `"status": "PENDING"`, `"qubits": 25`, `"shots": 1000`.

Poll until complete (usually 1-2 minutes):

```bash
# bash
while true; do
  R=$(curl -s "${API}jobs/$JOB"); S=$(echo "$R" | python -c "import sys, json; print(json.load(sys.stdin)['status'])")
  echo "$(date +%T) $S"; [ "$S" != "PENDING" ] && break; sleep 5
done
echo "$R" | python -m json.tool
```

```powershell
# PowerShell (GET /jobs returns 202 while pending, so read the body without throwing)
do {
  $R = Invoke-WebRequest -Uri "${API}jobs/$JOB" -SkipHttpErrorCheck | Select-Object -ExpandProperty Content | ConvertFrom-Json
  "{0} {1}" -f (Get-Date -Format T), $R.status
  if ($R.status -eq "PENDING") { Start-Sleep 5 }
} while ($R.status -eq "PENDING")
$R | ConvertTo-Json -Depth 6
```

**Expected result.** The verified answer is deterministic:

| Field | Expected |
|---|---|
| `status` / `method` | `COMPLETE` / `QUANTUM` |
| `total_cost` | **209000** |
| `greedy_cost` / `savings` | **233000** / **24000** |
| `combinations_evaluated` | 120 |
| `assignment` | Sarah → SQL Injection ($75,000), Marc → Data Exfiltration ($31,000), David → Ransomware ($56,000), Lisa → Phishing Campaign ($28,000), Chen → DDoS Attack ($19,000) |

The `qaoa` block reports what the quantum circuit measured. For this exact matrix, the simulator gives a per-shot probability of **0.395** for a valid assignment and **0.0385** for the optimal one. With 1,000 shots you should therefore see:

| Field | Expected range (99.7% of runs) | Reference run |
|---|---|---|
| `qaoa.feasible_fraction` | 0.35 - 0.44 | 0.391 |
| `qaoa.optimal_fraction` | 0.020 - 0.057 | 0.041 |
| `qaoa.qaoa_found_optimum` | `true` (the chance of no optimal shot in 1,000 is below 10⁻¹⁶) | `true` |
| `qaoa.qaoa_cost` / `qaoa.qaoa_gap_pct` | 209000 / 0.0 | 209000 / 0.0 |
| `qaoa.distinct_bitstrings` | around 500 (varies with sampling) | 494 |
| `qaoa.layers` / `qaoa.qubits` / `qaoa.shots` | 16 / 25 / 1000 | |

SV1 is an exact, noiseless simulator, so these numbers are statistically the same as the offline simulation in the next step.

### 5.4 Reproduce the QAOA performance table offline

From the repository root, with the dev requirements installed ([section 3](#3-run-the-tests-locally-optional)):

```bash
python tests/benchmark_qaoa.py
```

Expected output (deterministic: fixed seeds):

```
p=16  dgamma=3.2  dbeta=0.6  A=0.75  shots=1000
N  qubits  instances  P(valid)  P(optimal)  random-guess P(optimal)  best-sample=optimum  mean gap
3       9         20     0.665      0.3231                  2.0e-03           20/20          0.00%
4      16         20     0.710      0.1387                  1.5e-05           20/20          0.00%
```

The 25-qubit row needs about 1.5 GB of RAM and roughly 3 minutes per instance:

```bash
python tests/benchmark_qaoa.py --n 5 --instances 5
# 5      25          5     0.433      0.0489                  3.0e-08            5/5           0.00%
```

### 5.5 Check the security controls

```bash
# Invalid input is rejected with 400 and a clear message
curl -s -X POST "${API}optimize" -H "Content-Type: application/json" -d @../examples/invalid-request.json
# {"error": "every cost must be between 0 and 1,000,000,000"}

# Unknown job IDs: 400 for a non-UUID, 404 for an unknown UUID
curl -s -o /dev/null -w "%{http_code}\n" "${API}jobs/not-a-uuid"
curl -s -o /dev/null -w "%{http_code}\n" "${API}jobs/3f1c2b9e-8a4d-4e2f-9b6a-1c2d3e4f5a6b"

# Security headers on the website
curl -sI "$(terraform output -raw demo_url)" | grep -iE "content-security-policy|strict-transport|x-frame-options"
```

---

## 6. See it working inside AWS

| Where | What to look for |
|---|---|
| **Braket console → Tasks** | One task per 5×5 job, status `COMPLETED`, device `SV1`, 1,000 shots, tags `job_id` and `project` |
| **DynamoDB → Tables → `<prefix>-jobs` → Explore items** | One item per job with `status`, `assignment`, `qaoa` metrics; plus a `quota#YYYY-MM-DD` counter item |
| **S3 → `amazon-braket-<prefix>`** | `braket-results/<job_id>/.../results.json` with the raw measurements |
| **CloudWatch → Dashboards → `<prefix>-dashboard`** | Invocations, errors, latency and API traffic |
| **CloudWatch → Alarms** | Five alarms in `OK` state |

Follow the quantum Lambda's logs live:

```bash
aws logs tail /aws/lambda/<prefix>-braket --follow
# submit: job ... -> arn:aws:braket:... (5625 gates)
# complete: job ... feasible=0.391 gap=0.0
```

---

## 7. Configuration

All settings are Terraform variables (`rootTerraformCode/variables.tf`), set in `terraform.tfvars`:

| Variable | Default | Purpose |
|---|---|---|
| `alert_email` | (required) | Receives alarm notifications |
| `project` | `quantum-finance` | Prefix for every resource name. Must be globally unique for S3 |
| `environment` | `dev` | `dev`, `staging` or `prod` |
| `aws_region` | `us-east-1` | Deployment region |
| `bedrock_model_id` | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | Model for summaries; IAM is scoped to it automatically |
| `qaoa_layers` | `16` | QAOA depth p. Lower is faster and smaller but less accurate |
| `qaoa_shots` | `1000` | Measurements per quantum job |
| `max_quantum_jobs_per_day` | `50` | Daily cost cap for quantum jobs |
| `classical_threshold` | `4` | Largest N solved classically |
| `braket_device_arn` | SV1 | Quantum device. QPUs need code changes first (see README roadmap) |
| `extra_cors_origins` | `[]` | Extra browser origins, e.g. `["http://localhost:8080"]` to develop the frontend locally |

Changing the QAOA settings changes the expected numbers in [section 5.3](#53-quantum-path-5x5-on-amazon-braket). Re-run the benchmark with the new values to get updated expectations.

---

## 8. Costs

| Item | Cost driver | Typical |
|---|---|---|
| Lambda, API Gateway, DynamoDB, EventBridge, SNS | Per request; free tier covers demo traffic | ≈ $0 |
| CloudFront, S3 | Per request and GB transferred | ≈ $0 for a demo |
| Amazon Braket SV1 | Per minute of simulation (see [Braket pricing](https://aws.amazon.com/braket/pricing/)) | A few cents per 5×5 job |
| Amazon Bedrock (Claude Haiku 4.5) | Per token, a few hundred tokens per summary | Fractions of a cent per job |
| CloudWatch | Logs (7-day retention), 5 alarms, 1 dashboard | ≈ $0 within the free tier (10 alarms, 3 dashboards) |

The daily quota (`max_quantum_jobs_per_day`) and API throttling cap the worst case. To stop all charges, [tear down](#10-tear-down) the stack.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `terraform apply`: `BucketAlreadyExists` | Bucket names are global and the default prefix is taken | Set a unique `project` in `terraform.tfvars` |
| Website returns `AccessDenied` (XML) right after deploy | CloudFront is still propagating | Wait 5-10 minutes |
| Browser console: CORS error | Page opened from an origin other than `demo_url` | Use `demo_url`, or add your origin to `extra_cors_origins` |
| `"narrative_source": "fallback"` | Bedrock model access not granted, or throttled | Complete [2.2](#22-enable-claude-haiku-45-on-amazon-bedrock); check the classical Lambda logs |
| Quantum job `FAILED`: "could not be submitted" | Braket service-linked role missing, or circuit rejected | Check `aws logs tail /aws/lambda/<prefix>-braket` (in Git Bash, prefix with `MSYS_NO_PATHCONV=1`). Complete [2.1](#21-enable-amazon-braket). If the error mentions the action size, set `qaoa_layers = 12` |
| Quantum job stays `PENDING` for more than 5 minutes | EventBridge event not delivered | Check the task in the Braket console. If it is `COMPLETED`, check the `<prefix>-braket-task-complete` rule and the Braket Lambda logs |
| `429` on `POST /optimize` | Rate limit (1 rps) or the daily quantum quota | Wait a few seconds; the quota resets at 00:00 UTC |
| No alarm emails | SNS subscription not confirmed | Click the link in the confirmation email (check spam) |
| `pytest` import errors | Run from the repository root with the dev requirements installed | `pip install -r requirements-dev.txt` and run `pytest` from the root |

---

## 10. Tear down

```bash
cd rootTerraformCode
terraform destroy     # type "yes"
```

This removes everything, including the S3 buckets and their contents (`force_destroy` is enabled) and the CloudFront distribution (which takes a few minutes to disable). The Braket service-linked role and Bedrock model access from step 2 stay in place; they cost nothing.
