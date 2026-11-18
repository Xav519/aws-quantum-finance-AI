# Example requests

Ready-to-send bodies for `POST /optimize`, used by [SETUP.md](../SETUP.md#5-reproduce-the-results) to check that a deployment gives the same results as the documentation. (JSON files cannot contain comments, so they are explained here.)

| File | What it is | Expected result |
|---|---|---|
| `classical-3x3.json` | Top-left 3×3 corner of the README example | `200`, total **$185,000**, greedy $214,000, saved $29,000 (always identical) |
| `quantum-5x5.json` | The full 5×5 README example | `202` with a `job_id`; after ~45 s, total **$209,000**, saved $24,000, plus QAOA metrics (about 33-46 % valid shots, 2-6 % optimal) |
| `invalid-request.json` | A request with a negative cost | `400` `{"error": "every cost must be between 0 and 1,000,000,000"}` |

Example (bash, from the `rootTerraformCode` folder after `terraform apply`):

```bash
curl -s -X POST "$(terraform output -raw api_url)optimize" \
  -H "Content-Type: application/json" -d @../examples/classical-3x3.json
```
