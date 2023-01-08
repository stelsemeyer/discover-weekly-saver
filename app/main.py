import os

import functions_framework
from utils import _copy_tracks


@functions_framework.http
def copy_tracks(request):
    source_playlist_id = os.environ["SOURCE_PLAYLIST_ID"]
    destination_playlist_id = os.environ["DESTINATION_PLAYLIST_ID"]
    return _copy_tracks(source_playlist_id, destination_playlist_id)


# For local testing
if __name__ == "__main__":
    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ModuleNotFoundError:
        pass

    source_playlist_id = os.environ["SOURCE_PLAYLIST_ID"]
    destination_playlist_id = os.environ["DESTINATION_PLAYLIST_ID"]
    _copy_tracks(source_playlist_id, destination_playlist_id)
