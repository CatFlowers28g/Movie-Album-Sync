-- FLAC Combiner
-- Combines multiple FLAC files into a single file using ffmpeg concat demuxer

on run
	try
		-- Get FLAC files
		set flacFiles to choose file with prompt "Select FLAC files to combine (select one or multiple):" of type {"public.audio"} with multiple selections allowed
		
		if (count of flacFiles) < 2 then
			display dialog "Error: You must select at least 2 files!" buttons {"OK"} default button 1 with icon caution
			return
		end if
		
		-- Get output directory (same as first file's directory)
		set outputFolder to choose folder with prompt "Choose where to save the combined file:"
		
		-- Get output filename
		set defaultOutput to "Combined.flac"
		display dialog "Enter output filename:" default answer defaultOutput
		set outputFilename to text returned of result
		set outputPath to (POSIX path of outputFolder) & outputFilename
		
		-- Create concat list file
		set concatListPath to (POSIX path of outputFolder) & "flac_list.txt"
		set concatContent to ""
		
		repeat with flacFile in flacFiles
			set flacPath to POSIX path of flacFile
			set concatContent to concatContent & "file '" & flacPath & "'" & linefeed
		end repeat
		
		-- Write concat list to file
		set fileHandle to open for access concatListPath with write permission
		set eof fileHandle to 0
		write concatContent to fileHandle
		close access fileHandle
		
		-- Show confirmation dialog
		display dialog "Ready to combine " & (count of flacFiles) & " FLAC files:" & return & return & "Output: " & outputPath & return & return & "Concat list: " & concatListPath buttons {"Cancel", "Combine"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Build ffmpeg command
		set ffmpegCommand to "ffmpeg -y -f concat -safe 0 -i " & quoted form of concatListPath & " -c:a flac " & quoted form of outputPath
		
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "FLAC combination started! Check Terminal for progress." with title "FLAC Combiner"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
