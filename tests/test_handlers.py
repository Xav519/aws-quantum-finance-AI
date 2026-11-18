"""
Handler tests with in-memory fakes for DynamoDB, Lambda, Braket and S3.

They exercise the full quantum flow end to end:
POST /optimize -> PENDING record -> submit -> EventBridge completion -> GET /jobs/{id}.
"""

import importlib.util
import io
import json
import os

import pytest
from botocore.exceptions import ClientError

from conftest import ROOT

os.environ.update({
    "DYNAMODB_TABLE": "jobs",
    "LAMBDA_CLASSICAL": "classical",
    "LAMBDA_BRAKET": "braket",
    "BRAKET_DEVICE_ARN": "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
    "RESULTS_BUCKET": "amazon-braket-test",
    "PROJECT_TAG": "quantum-finance-test",
    "MAX_QUANTUM_JOBS_PER_DAY": "2",
})


def load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


orchestrator = load("orchestrator_handler", "modules/lambda_orchestrator/src/handler.py")
classical = load("classical_handler", "modules/lambda_classical/src/handler.py")
braket_handler = load("braket_handler", "modules/lambda_braket/src/handler.py")
get_job = load("get_job_handler", "modules/lambda_get_job/src/handler.py")


# --------------------------------------------------------------------------- #
# Fakes
# --------------------------------------------------------------------------- #
def _conditional_failure():
    return ClientError({"Error": {"Code": "ConditionalCheckFailedException", "Message": ""}}, "UpdateItem")


class FakeTable:
    """Implements just the DynamoDB expressions the handlers use."""

    def __init__(self):
        self.items = {}

    def get_item(self, Key):
        item = self.items.get(Key["job_id"])
        return {"Item": dict(item)} if item else {}

    def put_item(self, Item, ConditionExpression=None):
        if ConditionExpression and Item["job_id"] in self.items:
            raise _conditional_failure()
        self.items[Item["job_id"]] = dict(Item)

    def update_item(self, Key, UpdateExpression, ExpressionAttributeValues,
                    ExpressionAttributeNames=None, ConditionExpression=None):
        names = ExpressionAttributeNames or {}
        values = ExpressionAttributeValues
        item = self.items.setdefault(Key["job_id"], dict(Key))

        if UpdateExpression.startswith("ADD submitted"):  # quota counter
            if item.get("submitted", 0) >= values[":max"]:
                raise _conditional_failure()
            item["submitted"] = item.get("submitted", 0) + 1
            return
        if ConditionExpression == "#status = :pending" and item.get("status") != "PENDING":
            raise _conditional_failure()
        for assignment in UpdateExpression[len("SET "):].split(", "):
            name, value = (part.strip() for part in assignment.split("="))
            item[names.get(name, name)] = values[value]


class FakeLambda:
    def __init__(self):
        self.calls = []

    def invoke(self, FunctionName, InvocationType, Payload):
        payload = json.loads(Payload)
        self.calls.append((FunctionName, InvocationType, payload))
        if InvocationType == "Event":
            return {"StatusCode": 202}
        result = classical.lambda_handler(payload, None)
        return {"StatusCode": 200, "Payload": io.BytesIO(json.dumps(result).encode())}


class FakeBraket:
    def __init__(self):
        self.tasks = {}

    def create_quantum_task(self, **kwargs):
        arn = f"arn:aws:braket:us-east-1:123:quantum-task/{kwargs['clientToken']}"
        self.tasks[arn] = {**kwargs, "status": "COMPLETED", "quantumTaskArn": arn,
                           "outputS3Bucket": kwargs["outputS3Bucket"],
                           "outputS3Directory": f"{kwargs['outputS3KeyPrefix']}/task"}
        return {"quantumTaskArn": arn}

    def get_quantum_task(self, quantumTaskArn):
        return self.tasks[quantumTaskArn]


class FakeS3:
    def __init__(self, result):
        self.result = result

    def get_object(self, Bucket, Key):
        return {"Body": io.BytesIO(json.dumps(self.result).encode())}


@pytest.fixture
def env(monkeypatch):
    table, lam, brk = FakeTable(), FakeLambda(), FakeBraket()
    for module in (orchestrator, classical, braket_handler, get_job):
        monkeypatch.setattr(module, "table", table)
    monkeypatch.setattr(orchestrator, "lambda_client", lam)
    monkeypatch.setattr(braket_handler, "braket", brk)
    # Bedrock unavailable in tests: handlers must still complete via the fallback.
    monkeypatch.setattr("qf_common.bedrock._client", type("NoBedrock", (), {
        "invoke_model": lambda self, **_: (_ for _ in ()).throw(
            ClientError({"Error": {"Code": "AccessDenied", "Message": ""}}, "InvokeModel"))
    })())
    return table, lam, brk


def post(body):
    return orchestrator.lambda_handler({"body": json.dumps(body)}, None)


def request(n):
    return {
        "analysts": [f"Analyst {i}" for i in range(n)],
        "alerts": [f"Threat {i}" for i in range(n)],
        "cost_matrix": [[((i * 7 + j * 3) % 11 + 1) * 1000 for j in range(n)] for i in range(n)],
    }


# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #
def test_invalid_request_returns_400(env):
    resp = orchestrator.lambda_handler({"body": "{not json"}, None)
    assert resp["statusCode"] == 400


def test_classical_path_returns_result_synchronously(env):
    resp = post(request(4))
    body = json.loads(resp["body"])
    assert resp["statusCode"] == 200
    assert body["status"] == "COMPLETE" and body["method"] == "CLASSICAL"
    assert body["total_cost"] <= body["greedy_cost"]
    assert body["narrative_source"] == "fallback"
    assert len(body["assignment"]) == 4


def test_quantum_flow_end_to_end(env):
    table, lam, brk = env

    # 1. POST: 202 + PENDING record written before the async dispatch
    resp = post(request(5))
    assert resp["statusCode"] == 202
    job_id = json.loads(resp["body"])["job_id"]
    assert table.items[job_id]["status"] == "PENDING"
    assert lam.calls[-1] == ("braket", "Event", {"action": "submit", "job_id": job_id})

    # 2. GET while pending -> 202
    assert get_job.lambda_handler({"pathParameters": {"job_id": job_id}}, None)["statusCode"] == 202

    # 3. Submit: creates one tagged task, idempotent on retry
    braket_handler.lambda_handler({"action": "submit", "job_id": job_id}, None)
    braket_handler.lambda_handler({"action": "submit", "job_id": job_id}, None)
    assert len(brk.tasks) == 1
    task_arn, task = next(iter(brk.tasks.items()))
    assert task["tags"]["job_id"] == job_id
    assert table.items[job_id]["braket_task_arn"] == task_arn

    # 4. Completion: a measurement result where every shot is the optimum
    cost = json.loads(table.items[job_id]["cost_matrix"])
    from qf_common.solver import solve_exact
    best, best_cost = solve_exact(cost)
    bits = [1 if best[i] == j else 0 for i in range(5) for j in range(5)]
    braket_handler.s3 = FakeS3({"measurements": [bits] * 10, "measuredQubits": list(range(25))})
    event = {"source": "aws.braket", "detail": {"quantumTaskArn": task_arn, "status": "COMPLETED"}}
    braket_handler.lambda_handler(event, None)
    braket_handler.lambda_handler(event, None)  # duplicate event is ignored

    # 5. GET -> 200 with the verified optimum and QAOA metrics
    resp = get_job.lambda_handler({"pathParameters": {"job_id": job_id}}, None)
    body = json.loads(resp["body"])
    assert resp["statusCode"] == 200
    assert body["status"] == "COMPLETE"
    assert body["total_cost"] == best_cost
    assert body["qaoa"]["qaoa_found_optimum"] is True
    assert body["qaoa"]["feasible_fraction"] == 1.0


def test_failed_braket_task_marks_job_failed(env):
    table, _, brk = env
    job_id = json.loads(post(request(5))["body"])["job_id"]
    braket_handler.lambda_handler({"action": "submit", "job_id": job_id}, None)
    task_arn = next(iter(brk.tasks))
    brk.tasks[task_arn]["status"] = "FAILED"
    braket_handler.lambda_handler({"source": "aws.braket", "detail": {"quantumTaskArn": task_arn}}, None)

    body = json.loads(get_job.lambda_handler({"pathParameters": {"job_id": job_id}}, None)["body"])
    assert body["status"] == "FAILED" and "FAILED" in body["error"]


def test_foreign_braket_tasks_are_ignored(env):
    _, _, brk = env
    brk.tasks["arn:other"] = {"status": "COMPLETED", "tags": {"job_id": "x", "project": "someone-else"}}
    out = braket_handler.lambda_handler({"source": "aws.braket", "detail": {"quantumTaskArn": "arn:other"}}, None)
    assert out["status"] == "IGNORED"


def test_daily_quantum_quota(env):
    assert post(request(5))["statusCode"] == 202
    assert post(request(5))["statusCode"] == 202
    assert post(request(5))["statusCode"] == 429


@pytest.mark.parametrize("job_id,status", [("not-a-uuid", 400), ("quota#2026-01-01", 400),
                                           ("3f1c2b9e-8a4d-4e2f-9b6a-1c2d3e4f5a6b", 404)])
def test_get_job_rejects_bad_or_unknown_ids(env, job_id, status):
    assert get_job.lambda_handler({"pathParameters": {"job_id": job_id}}, None)["statusCode"] == status
