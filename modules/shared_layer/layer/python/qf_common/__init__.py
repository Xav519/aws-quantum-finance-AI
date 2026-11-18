"""
==============================================================================
modules/shared_layer/layer/python/qf_common/__init__.py
------------------------------------------------------------------------------
PURPOSE
  Marks qf_common as a Python package (shared code deployed as a Lambda layer).

DETAILS
  Modules:
    solver.py  -> exact and greedy assignment solvers
    bedrock.py -> board summary from Claude on Amazon Bedrock, with fallback
    jobs.py    -> job record helpers (DynamoDB item <-> API response)
    http.py    -> API Gateway JSON response helper
==============================================================================
"""
