import json
import logging
import os
from typing import Iterable

import spotipy
from google.api_core.exceptions import FailedPrecondition
from google.cloud import secretmanager
from spotipy.cache_handler import CacheHandler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


SPOTIFY_CLIENT_SCOPE = "playlist-modify-private"


def create_spotify_client(
    spotify_client_id: str = None,
    spotify_client_secret: str = None,
    spotify_redirect_uri: str = None,
    gcp_project_id: str = None,
    gcp_secret_id: str = None,
) -> spotipy.Spotify:
    """A helper function to initialize the spotity client with Google Secret Manager cache handler."""
    if spotify_client_id is None:
        spotify_client_id = os.environ["SPOTIFY_CLIENT_ID"]
    if spotify_client_secret is None:
        spotify_client_secret = os.environ["SPOTIFY_CLIENT_SECRET"]
    if spotify_redirect_uri is None:
        spotify_redirect_uri = os.environ["SPOTIFY_REDIRECT_URI"]
    if gcp_project_id is None:
        gcp_project_id = os.environ["GCP_PROJECT_ID"]
    if gcp_secret_id is None:
        gcp_secret_id = os.environ["GCP_SECRET_ID"]

    auth_manager = spotipy.oauth2.SpotifyOAuth(
        client_id=spotify_client_id,
        client_secret=spotify_client_secret,
        redirect_uri=spotify_redirect_uri,
        scope=SPOTIFY_CLIENT_SCOPE,
        cache_handler=GoogleSecretManagerCacheHandler(
            project_id=gcp_project_id,
            secret_id=gcp_secret_id,
        ),
    )
    token = auth_manager.get_access_token(as_dict=False)
    return spotipy.Spotify(auth=token)


def get_playlist_tracks(spotify_client, playlist_id: str) -> list:
    """A helper function to get the tracks of a specific playlist."""
    tracks = []
    result = spotify_client.playlist_items(playlist_id, additional_types=["track"])
    tracks.extend(result["items"])

    while result["next"]:
        logger.info("Fetching more tracks.")
        result = spotify_client.next(result)
        tracks.extend(result["items"])

    logger.info(f"Playlist {playlist_id} contains {len(tracks)} tracks.")
    return tracks


def chunker(seq: Iterable, size: int):
    """A helper function to iterate in chunks."""
    return (seq[pos : pos + size] for pos in range(0, len(seq), size))  # noqa: E203


def _copy_tracks(source_playlist_id: str, destination_playlist_id: str) -> str:
    """A function to get copy tracks from one to another playlist, avoiding duplication."""
    logger.info("Copying tracks.")
    spotify_client = create_spotify_client()
    destination_tracks = get_playlist_tracks(spotify_client, destination_playlist_id)
    source_tracks = get_playlist_tracks(spotify_client, source_playlist_id)

    destination_track_uris = [track["track"]["uri"] for track in destination_tracks]

    new_source_tracks_uris = []
    for source_track in source_tracks:
        if source_track["track"]["uri"] not in destination_track_uris:
            new_source_tracks_uris.append(source_track["track"]["uri"])
    logger.info(f"Found {len(new_source_tracks_uris)}/{len(source_tracks)} new tracks.")

    for chunk in chunker(new_source_tracks_uris, 100):
        logger.info(f"Sending chunk to {destination_playlist_id}")
        spotify_client.playlist_add_items(destination_playlist_id, chunk)

    logger.info(f"Done. Copied {len(new_source_tracks_uris)} tracks.")
    return "OK"


def request_spotify_user_auth(
    spotify_client_id: str,
    spotify_client_secret: str,
    spotify_redirect_uri: str,
    gcp_project_id: str,
    gcp_secret_id: str,
) -> bool:
    """A helper function to initialize authentication with Spotify through OAuth."""
    auth_manager = spotipy.oauth2.SpotifyOAuth(
        client_id=spotify_client_id,
        client_secret=spotify_client_secret,
        redirect_uri=spotify_redirect_uri,
        scope=SPOTIFY_CLIENT_SCOPE,
        show_dialog=True,
        cache_handler=GoogleSecretManagerCacheHandler(
            project_id=gcp_project_id, secret_id=gcp_secret_id
        ),
    )
    token = auth_manager.get_access_token(
        as_dict=False,
        check_cache=False,
    )
    return token is not None


class GoogleSecretManagerCacheHandler(CacheHandler):
    """An extension of the spotipy CacheHandler to handle the caching and retrieval of
    authorization tokens to and from Google Secret Manager."""

    def __init__(self, project_id: str = None, secret_id: str = None):
        if not project_id:
            project_id = os.environ["GCP_PROJECT_ID"]
        if not secret_id:
            secret_id = os.environ["GCP_SECRET_ID"]

        self.project_id = project_id
        self.secret_id = secret_id

    @property
    def _client(self) -> secretmanager.SecretManagerServiceClient:
        return secretmanager.SecretManagerServiceClient()

    @property
    def _parent(self):
        return f"projects/{self.project_id}/secrets/{self.secret_id}"

    def get_cached_token(self) -> str:
        name = f"{self._parent}/versions/latest"
        response = self._client.access_secret_version(name=name)
        return json.loads(response.payload.data.decode("UTF-8"))

    def save_token_to_cache(
        self, token_info: dict, delete_old_versions: bool = True
    ) -> None:
        logger.info("Saving token to cache.")
        data = json.dumps(token_info).encode("UTF-8")
        _ = self._client.add_secret_version(parent=self._parent, payload={"data": data})
        if delete_old_versions:
            self._delete_old_versions()
        return None

    def _delete_old_versions(self) -> None:
        """A helper to destroy old versions to reduce Secret storage cost."""
        logger.debug("Deleting old versions.")
        latest_version = self._client.get_secret_version(
            {"name": f"{self._parent}/versions/latest"}
        )
        logger.debug(f"Latest version is {latest_version.name}.")
        for version in self._client.list_secret_versions({"parent": self._parent}):
            if version.name != latest_version.name and version.state.name != "DESTROYED":  # fmt: skip
                logger.debug(f"Deleting version {version.name}.")
                try:
                    self._client.destroy_secret_version({"name": version.name})
                except FailedPrecondition:
                    logger.debug(f"Failed to delete version {version.name}.")
                    # Skip if already destroyed
                    pass
        return
