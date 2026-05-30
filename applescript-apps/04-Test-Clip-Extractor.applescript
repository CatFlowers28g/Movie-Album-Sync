-- Test Clip Extractor
-- Extracts a short segment from beginning of video with audio sync applied
-- Useful for testing if audio sync timing is correct before full encoding

on run
	try
		-- Get video file
		set videoFile to choose file with prompt "Select the video file (MKV or MP4):" of type {"mp4", "mkv", "mov"}
		set videoPath to POSIX path of videoFile
		
		-- Get audio file
		set audioFile to choose file with prompt "Select the audio file (FLAC or MP3):" of type {"mp3", "flac", "wav", "m4a"}
		set audioPath to POSIX path of audioFile
		
		-- Get clip duration in minutes
		display dialog "Extract first how many minutes? (default: 3):" default answer "3"
		set durationMinutes to text returned of result
		
		-- Validate duration is a number
		try
			set durationMinutes to durationMinutes as integer
		on error
			display dialog "Error: Duration must be a number!" buttons {"OK"} default button 1 with icon caution
			return
		end try
		
		-- Convert minutes to seconds
		set durationSeconds to durationMinutes * 60
		
		-- Get audio delay in milliseconds
		display dialog "Enter audio delay in milliseconds (default: 36000ms = 36 seconds):" default answer "36000"
		set audioDelay to text returned of result
		
		-- Validate delay is a number
		try
			set audioDelay to audioDelay as integer
		on error
			display dialog "Error: Audio delay must be a number!" buttons {"OK"} default button 1 with icon caution
			return
		end try
		
		-- Get output filename
		set defaultOutput to "TEST_" & durationMinutes & "min.mkv"
		display dialog "Enter output filename:" default answer defaultOutput
		set outputFilename to text returned of result
		
		-- Get output directory
		set outputFolder to choose folder with prompt "Choose where to save the test clip:"
		set outputPath to (POSIX path of outputFolder) & outputFilename
		
		-- Build ffmpeg command with trimming and audio sync
		set ffmpegCommand to "ffmpeg -ss 0 -i " & quoted form of videoPath & " -stream_loop -1 -i " & quoted form of audioPath & " -t " & durationSeconds & " -filter_complex \"[1:a]adelay=" & audioDelay & "|" & audioDelay & ",apad[aud]\" -map 0:v -map \"[aud]\" -c:v copy -c:a flac " & quoted form of outputPath
		
		-- Show confirmation dialog
		display dialog "Ready to extract test clip:" & return & return & "Video: " & videoPath & return & "Audio: " & audioPath & return & "Duration: " & durationMinutes & " minutes" & return & "Audio Delay: " & audioDelay & "ms" & return & "Output: " & outputPath buttons {"Cancel", "Extract"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Run ffmpeg command in a visible terminal window for progress feedback
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "Test clip extraction started! Check Terminal for progress." with title "Test Clip Extractor"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
