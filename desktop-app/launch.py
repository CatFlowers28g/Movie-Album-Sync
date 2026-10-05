# Entry point for PyInstaller builds (it can't use the package's __main__ directly)
import sys

from movie_album_sync.app import main

sys.exit(main())
