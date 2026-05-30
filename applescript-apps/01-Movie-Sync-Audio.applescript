-- Movie Sync Audio to Video
-- Syncs an audio track to a video file with customizable delay
-- Uses ffmpeg with adelay and apad filters

on run
	try
		-- Get video file
		set videoFile to choose file with prompt "Select the video file (MKV or MP4):" of type {"public.video"}
		set videoPath to POSIX path of videoFile
		
		-- Get audio file
		set audioFile to choose file with prompt "Select the audio file (FLAC or MP3):" of type {"public.audio"}
		set audioPath to POSIX path of audioFile
		
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
		set defaultOutput to "SyncedOutput.mkv"
		display dialog "Enter output filename:" default answer defaultOutput
		set outputFilename to text returned of result
		
		-- Get output directory
		set outputFolder to choose folder with prompt "Choose where to save the output file:"
		set outputPath to (POSIX path of outputFolder) & outputFilename
		
		-- Build ffmpeg command
		set ffmpegCommand to "ffmpeg -i " & quoted form of videoPath & " -stream_loop -1 -i " & quoted form of audioPath & " -filter_complex \"[1:a]adelay=" & audioDelay & "|" & audioDelay & ",apad[aud]\" -map 0:v -map \"[aud]\" -c:v copy -c:a flac -shortest " & quoted form of outputPath
		
		-- Show confirmation dialog
		display dialog "Ready to process:" & return & return & "Video: " & videoPath & return & "Audio: " & audioPath & return & "Delay: " & audioDelay & "ms" & return & "Output: " & outputPath buttons {"Cancel", "Process"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Run ffmpeg command in a visible terminal window for progress feedback
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "Processing started! Check Terminal for progress." with title "Movie Sync Audio"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
