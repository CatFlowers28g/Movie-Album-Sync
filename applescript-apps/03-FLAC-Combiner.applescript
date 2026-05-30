-- FLAC Combiner
-- Combines multiple FLAC files into a single file using ffmpeg concat demuxer

-- Helper function to escape special characters
on replace_text(theText, oldChar, newChar)
	set AppleScript's text item delimiters to oldChar
	set textItems to text items of theText
	set AppleScript's text item delimiters to newChar
	return textItems as text
end replace_text

on run
	try
		-- Ask how user wants to select files
		set selectionMethod to choose from list {"Add files one-by-one (choose order)", "Select all files at once"} with title "Track Selection" with prompt "How would you like to select tracks?"
		
		if selectionMethod is false then
			return
		end if
		
		set selectionMethod to item 1 of selectionMethod
		set flacFiles to {}
		
		if selectionMethod is "Add files one-by-one (choose order)" then
			-- Let user add files in order
			repeat
				set userChoice to choose from list {"Add another track", "Done - ready to combine"} with title "Track Order" with prompt "Selected tracks: " & (count of flacFiles)
				
				if userChoice is false or item 1 of userChoice is "Done - ready to combine" then
					exit repeat
				end if
				
				-- Add file to list
				set newFile to choose file with prompt "Select track #" & ((count of flacFiles) + 1) & " (in order):" of type {"public.audio"}
				set end of flacFiles to newFile
				
				-- Show the file that was added
				display notification "Added track #" & (count of flacFiles) & ": " & (name of newFile) with title "FLAC Combiner"
			end repeat
		else
			-- Select all files at once
			set flacFiles to choose file with prompt "Select all FLAC files to combine:" of type {"public.audio"} with multiple selections allowed
		end if
		
		if (count of flacFiles) < 2 then
			display dialog "Error: You must select at least 2 files!" buttons {"OK"} default button 1 with icon caution
			return
		end if
		
		-- Show files in order
		set orderText to ""
		repeat with i from 1 to count of flacFiles
			set orderText to orderText & i & ". " & (name of item i of flacFiles) & return
		end repeat
		
		display dialog "Files will be combined in this order:" & return & return & orderText buttons {"Cancel", "Proceed"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Get output directory
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
			-- Escape single quotes and backslashes for concat demuxer
			set flacPath to replace_text(flacPath, "'", "\\'")
			set concatContent to concatContent & "file '" & flacPath & "'" & linefeed
		end repeat
		
		-- Write concat list to file
		set fileHandle to open for access concatListPath with write permission
		set eof fileHandle to 0
		write concatContent to fileHandle
		close access fileHandle
		
		-- Build ffmpeg command (map only audio stream, skip video/album art)
		set ffmpegCommand to "ffmpeg -y -f concat -safe 0 -i " & quoted form of concatListPath & " -map 0:a -c:a flac " & quoted form of outputPath
		
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "FLAC combination started! Check Terminal for progress." with title "FLAC Combiner"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
