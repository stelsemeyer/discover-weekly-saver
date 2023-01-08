import os

import functions_framework
from utils import _copy_tracks

SOURCE_PLAYLIST_ID = os.environ.get("SOURCE_PLAYLIST_ID")
DESTINATION_PLAYLIST_ID = os.environ.get("DESTINATION_PLAYLIST_ID")  # fmt: skip


@functions_framework.http
def copy_tracks(request):
    return _copy_tracks(SOURCE_PLAYLIST_ID, DESTINATION_PLAYLIST_ID)


# For local testing
if __name__ == "__main__":
    try:
        from dotenv import load_dotenv

        load_dotenv()
    except ModuleNotFoundError:
        pass
    _copy_tracks(SOURCE_PLAYLIST_ID, DESTINATION_PLAYLIST_ID)
