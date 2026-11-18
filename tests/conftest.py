import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Make Lambda source importable the same way the Lambda runtime does:
# layer code under /opt/python, function code at the zip root.
for path in (
    os.path.join(ROOT, "modules", "shared_layer", "layer", "python"),
    os.path.join(ROOT, "modules", "lambda_braket", "src"),
    os.path.join(ROOT, "modules", "lambda_orchestrator", "src"),
    os.path.join(ROOT, "tests"),
):
    if path not in sys.path:
        sys.path.insert(0, path)

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("BEDROCK_MODEL", "test-model")
