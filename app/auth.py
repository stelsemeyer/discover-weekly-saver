import os

from utils import request_spotify_user_auth

request_spotify_user_auth(
    spotify_client_id=os.environ["SPOTIFY_CLIENT_ID"],
    spotify_client_secret=os.environ["SPOTIFY_CLIENT_SECRET"],
    spotify_redirect_uri=os.environ["SPOTIFY_REDIRECT_URI"],
    gcp_project_id=os.environ["GCP_PROJECT_ID"],
    gcp_secret_id=os.environ["GCP_SECRET_ID"],
)
