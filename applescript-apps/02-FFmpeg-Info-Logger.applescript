-- FFmpeg Info Logger
-- Generates detailed ffmpeg information log for a media file

on run
	try
		-- Get media file
		set mediaFile to choose file with prompt "Select media file (MKV, MP4, FLAC, etc):" of type {"public.video", "public.audio"}
		set mediaPath to POSIX path of mediaFile
		
		-- Get filename without extension for output
		set fileName to name of (info for mediaFile)
		set baseName to text 1 thru ((length of fileName) - (length of (fileName's extension)) - 1) of fileName
		
		-- Get output directory
		set outputFolder to choose folder with prompt "Choose where to save the log file:"
		set logPath to (POSIX path of outputFolder) & baseName & "_ffmpeg_log.txt"
		
		-- Show confirmation dialog
		display dialog "Ready to analyze:" & return & return & "File: " & mediaPath & return & "Output: " & logPath buttons {"Cancel", "Analyze"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Build and run ffmpeg command
		set ffmpegCommand to "ffmpeg -i " & quoted form of mediaPath & " -f null - > " & quoted form of logPath & " 2>&1"
		
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "Analysis started! Check Terminal for progress." with title "FFmpeg Info Logger"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
