import unittest

from movie_album_sync import themes


class PresetReadabilityTest(unittest.TestCase):
    def test_text_is_readable_on_background_and_panels(self):
        for name, theme in themes.PRESETS.items():
            with self.subTest(name):
                self.assertGreaterEqual(themes.contrast(theme.text, theme.background), 7, "text on background")
                self.assertGreaterEqual(themes.contrast(theme.text, theme.panel), 7, "text on panels")

    def test_button_text_is_readable_on_accent(self):
        for name, theme in themes.PRESETS.items():
            with self.subTest(name):
                self.assertGreaterEqual(themes.contrast(themes.text_on(theme.accent), theme.accent), 4.5)

    def test_accent_stands_out_from_background(self):
        for name, theme in themes.PRESETS.items():
            with self.subTest(name):
                self.assertGreaterEqual(themes.contrast(theme.accent, theme.background), 3)


class HelpersTest(unittest.TestCase):
    def test_text_on(self):
        self.assertEqual(themes.text_on("#FFCB05"), "#000000")
        self.assertEqual(themes.text_on("#5B21B6"), "#FFFFFF")

    def test_json_round_trip(self):
        theme = themes.PRESETS["Matrix"]
        self.assertEqual(themes.theme_from_json(themes.theme_to_json(theme)), theme)

    def test_bad_json_is_rejected(self):
        self.assertIsNone(themes.theme_from_json("not json"))
        self.assertIsNone(themes.theme_from_json('{"background": "nope", "panel": "#fff", "text": "#000", "accent": "#f00"}'))
        self.assertIsNone(themes.theme_from_json('{"background": "#000"}'))


if __name__ == "__main__":
    unittest.main()
