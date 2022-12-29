import os
import subprocess

import pytest
import requests

PORT = 14777


def test_http_integration():
    process = subprocess.Popen(
        ["functions-framework", "--target", "copy_tracks", "--dry-run"],
        cwd=os.path.join(os.path.dirname(__file__), "../app"),
        stdout=subprocess.PIPE,
    )

    process.kill()


@pytest.mark.skipif(
    os.environ.get("PYTEST_RUN_FULL_HTTP_INTEGRATION_TEST", "false").lower() != "true",
    reason="Skipping full integration test. To run it set PYTEST_RUN_FULL_HTTP_INTEGRATION_TEST=True.",
)
def test_full_http_integration():
    # Environment can be passed implicitly or explicitly as below
    env = {
        **os.environ.copy(),
        "SPOTIFY_CLIENT_ID": "...",
        "SPOTIFY_CLIENT_SECRET": "...",
        "SPOTIFY_REDIRECT_URI": "...",
        "GCP_PROJECT_ID": "...",
        "GCP_SECRET_ID": "...",
    }
    process = subprocess.Popen(
        ["functions-framework", "--target", "copy_tracks", "--port", str(PORT)],
        env=env,
        cwd=os.path.join(os.path.dirname(__file__), "../app"),
        stdout=subprocess.PIPE,
    )
    resp = requests.post(f"http://localhost:{PORT}", data={})
    process.kill()
    assert resp.status_code == 200
