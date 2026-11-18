import json
from decimal import Decimal

from botocore.exceptions import ClientError

from qf_common import bedrock, jobs
from qf_common.http import json_response
from qf_common.solver import solve_exact, solve_greedy

# The 5 x 5 example from the README (in $ thousands).
README_MATRIX = [
    [72, 95, 98, 75, 37],
    [112, 31, 67, 99, 49],
    [56, 65, 111, 106, 34],
    [61, 120, 28, 77, 115],
    [107, 101, 10, 81, 19],
]


def test_readme_example_optimum_and_greedy_baseline():
    assignment, cost = solve_exact(README_MATRIX)
    assert assignment == [3, 1, 0, 2, 4]
    assert cost == 209
    _, greedy = solve_greedy(README_MATRIX)
    assert greedy == 233


def test_to_dynamo_converts_floats_recursively():
    out = jobs.to_dynamo({"a": 1.5, "b": [0.25, 2], "c": {"d": None, "e": True}})
    assert out == {"a": Decimal("1.5"), "b": [Decimal("0.25"), 2], "c": {"d": None, "e": True}}


def test_result_view_for_completed_quantum_job():
    item = {
        "job_id": "j", "status": "COMPLETE", "method": "QUANTUM",
        "analysts": ["A", "B"], "alerts": ["X", "Y"],
        "cost_matrix": json.dumps([[1, 5], [4, 2]]),
        "assignment": [Decimal(0), Decimal(1)],
        "total_cost": Decimal(3), "greedy_cost": Decimal(3), "savings": Decimal(0),
        "qaoa": {"qaoa_assignment": [Decimal(1), Decimal(0)], "qaoa_cost": Decimal(9)},
    }
    view = jobs.result_view(item)
    assert view["assignment"] == [
        {"analyst": "A", "alert": "X", "cost": 1},
        {"analyst": "B", "alert": "Y", "cost": 2},
    ]
    assert view["qaoa"]["qaoa_assignment"][0] == {"analyst": "A", "alert": "Y", "cost": 5}
    # Serialises cleanly through the HTTP helper (Decimal -> int)
    body = json.loads(json_response(200, view)["body"])
    assert body["total_cost"] == 3


def test_result_view_for_pending_and_failed_jobs():
    assert "message" in jobs.result_view({"job_id": "j", "status": "PENDING"})
    failed = jobs.result_view({"job_id": "j", "status": "FAILED", "error": "boom"})
    assert failed["error"] == "boom"


class _FailingBedrock:
    def invoke_model(self, **_):
        raise ClientError({"Error": {"Code": "ThrottlingException", "Message": "slow down"}}, "InvokeModel")


class _Body:
    def __init__(self, payload):
        self._payload = payload

    def read(self):
        return json.dumps(self._payload).encode()


class _OkBedrock:
    def __init__(self, payload):
        self.payload = payload
        self.request = None

    def invoke_model(self, **kwargs):
        self.request = json.loads(kwargs["body"])
        return {"body": _Body(self.payload)}


def test_bedrock_failure_falls_back(monkeypatch):
    monkeypatch.setattr(bedrock, "_client", _FailingBedrock())
    assert bedrock.generate_narrative("prompt", "fallback text") == ("fallback text", "fallback")


def test_bedrock_success_uses_system_prompt(monkeypatch):
    fake = _OkBedrock({"stop_reason": "end_turn", "content": [{"type": "text", "text": " Summary. "}]})
    monkeypatch.setattr(bedrock, "_client", fake)
    assert bedrock.generate_narrative("prompt", "fallback") == ("Summary.", "bedrock")
    assert "never claim a quantum speed-up" in fake.request["system"]


def test_bedrock_empty_or_refused_response_falls_back(monkeypatch):
    monkeypatch.setattr(bedrock, "_client", _OkBedrock({"stop_reason": "refusal", "content": []}))
    assert bedrock.generate_narrative("prompt", "fb") == ("fb", "fallback")
