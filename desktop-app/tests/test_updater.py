import unittest

from movie_album_sync import updater

RELEASE_JSON = {
    "tag_name": "v1.2.0",
    "body": "Added a Star Wars theme",
    "html_url": "https://github.com/CatFlowers28g/Movie-Album-Sync/releases/tag/v1.2.0",
    "assets": [
        {"name": "MovieAlbumSync-1.2.0-Portable.zip", "browser_download_url": "https://example.com/zip", "size": 1},
        {"name": "MovieAlbumSync-1.2.0-Setup.exe", "browser_download_url": "https://example.com/exe", "size": 2},
        {"name": "MovieAlbumSync-1.2.0-Mac-Intel.dmg", "browser_download_url": "https://example.com/intel", "size": 3},
        {"name": "MovieAlbumSync-1.2.0-Mac-AppleSilicon.dmg", "browser_download_url": "https://example.com/arm", "size": 4},
    ],
}


class VersionTest(unittest.TestCase):
    def test_versions_compare_as_numbers(self):
        self.assertTrue(updater.is_newer("1.10.0", "1.9.3"))
        self.assertTrue(updater.is_newer("v1.2.1", "1.2.0"))
        self.assertFalse(updater.is_newer("1.2.0", "1.2.0"))
        self.assertFalse(updater.is_newer("1.1.9", "1.2.0"))

    def test_unreadable_version_is_never_newer(self):
        self.assertFalse(updater.is_newer("nightly", "1.0.0"))


class ParseReleaseTest(unittest.TestCase):
    def test_picks_this_platforms_download(self):
        self.assertEqual(updater.parse_release(RELEASE_JSON, "-Setup.exe").download_url, "https://example.com/exe")
        self.assertEqual(updater.parse_release(RELEASE_JSON, "-Mac-AppleSilicon.dmg").download_size, 4)

    def test_reads_version_and_notes(self):
        release = updater.parse_release(RELEASE_JSON, "-Setup.exe")
        self.assertEqual((release.version, release.notes), ("1.2.0", "Added a Star Wars theme"))

    def test_missing_download(self):
        release = updater.parse_release(RELEASE_JSON, "")
        self.assertEqual(release.download_url, "")
        self.assertFalse(updater.can_install(release))


if __name__ == "__main__":
    unittest.main()
