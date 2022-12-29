from unittest import mock

from utils import _copy_tracks


def test_copy_tracks():
    with (
        mock.patch("utils.create_spotify_client"),
        mock.patch("utils.get_playlist_tracks"),
    ):
        assert _copy_tracks(None, None) == "OK"
