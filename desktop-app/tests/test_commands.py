import unittest

from movie_album_sync import commands


class SyncArgsTest(unittest.TestCase):
    def test_positive_offset_delays_audio_and_copies_video(self):
        args = commands.sync_args("movie.mkv", "album.flac", 36000, "out.mkv")
        self.assertEqual(args, [
            "-i", "movie.mkv", "-stream_loop", "-1", "-i", "album.flac",
            "-filter_complex", "[1:a]adelay=36000|36000,apad[aud]",
            "-map", "0:v", "-map", "[aud]", "-c:v", "copy", "-c:a", "flac",
            "-shortest", "out.mkv",
        ])

    def test_negative_offset_pads_black_video(self):
        args = commands.sync_args("movie.mkv", "album.flac", -5250, "out.mkv")
        self.assertIn("[0:v]tpad=start_duration=5.25:start_mode=add:color=black[v];[1:a]apad[aud]", args)
        self.assertEqual(args[args.index("-c:v") + 1], "libx264")

    def test_mp4_uses_aac_and_tags_copied_hevc(self):
        args = commands.sync_args("movie.mkv", "album.flac", 1000, "out.mp4", mp4=True, hevc_video=True)
        self.assertEqual(args[-12:], ["-c:v", "copy", "-c:a", "aac", "-b:a", "320k", "-tag:v", "hvc1",
                                      "-movflags", "+faststart", "-shortest", "out.mp4"])

    def test_mp4_negative_offset_skips_hevc_tag(self):
        args = commands.sync_args("movie.mkv", "album.flac", -1000, "out.mp4", mp4=True, hevc_video=True)
        self.assertNotIn("-tag:v", args)
        self.assertIn("+faststart", args)

    def test_preview_limits_length(self):
        args = commands.sync_args("movie.mkv", "album.flac", 0, "out.mkv", preview_seconds=180)
        self.assertEqual(args[args.index("-t") + 1], "180")
        self.assertLess(args.index("-t"), args.index("-filter_complex"))


class HelpersTest(unittest.TestCase):
    def test_format_seconds(self):
        self.assertEqual(commands.format_seconds(5000), "5")
        self.assertEqual(commands.format_seconds(5250), "5.25")
        self.assertEqual(commands.format_seconds(1), "0.001")

    def test_concat_list_escapes_quotes_and_backslashes(self):
        text = commands.concat_list([r"C:\Music\Don't Stop.flac", "/a/b.flac"])
        self.assertEqual(text, "file 'C:/Music/Don'\\''t Stop.flac'\nfile '/a/b.flac'\n")

    def test_transcode_copy_with_resize_switches_to_h264(self):
        args = commands.transcode_args("in.mkv", "out.mp4", commands.KEEP_VIDEO, 720, "Keep original")
        self.assertEqual(args, ["-i", "in.mkv", "-vf", "scale=-2:720", "-c:v", "libx264", "-preset", "slow",
                                "-crf", "18", "-c:a", "copy", "-movflags", "+faststart", "out.mp4"])

    def test_transcode_without_resize(self):
        args = commands.transcode_args("in.mkv", "out.mkv", commands.H265_VIDEO, 0, "FLAC (lossless)")
        self.assertNotIn("-vf", args)
        self.assertIn("libx265", args)

    def test_parse_duration(self):
        self.assertAlmostEqual(commands.parse_duration("  Duration: 01:02:03.50, start: 0"), 3723.5)
        self.assertIsNone(commands.parse_duration("Duration: N/A"))

    def test_natural_sort(self):
        names = ["Track 10.flac", "track 2.flac", "Track 1.flac"]
        self.assertEqual(sorted(names, key=commands.natural_sort_key), ["Track 1.flac", "track 2.flac", "Track 10.flac"])


if __name__ == "__main__":
    unittest.main()
