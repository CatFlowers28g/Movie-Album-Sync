-- Video and Audio Re-Encoder
-- Re-encodes video and/or audio files with customizable resolution, format, and quality
-- Supports multiple codecs, resolutions, and audio quality presets

on run
	try
		-- Initialize variables
		set videoFile to missing value
		set audioFile to missing value
		set videoPath to ""
		set audioPath to ""
		
		-- Ask if user wants to process video and/or audio
		set encodeChoice to choose from list {"Video Only", "Audio Only", "Both"} with title "Re-Encoder" with prompt "What would you like to re-encode?"
		
		if encodeChoice is false then
			return
		end if
		
		set encodeChoice to item 1 of encodeChoice
		
		-- Get video file if needed
		if encodeChoice is "Video Only" or encodeChoice is "Both" then
			set videoFile to choose file with prompt "Select the video file to re-encode:" of type {"public.video", "public.mpeg-4"}
			set videoPath to POSIX path of videoFile
		end if
		
		-- Get audio file if needed
		if encodeChoice is "Audio Only" or encodeChoice is "Both" then
			set audioFile to choose file with prompt "Select the audio file to re-encode:" of type {"public.audio"}
			set audioPath to POSIX path of audioFile
		end if
		
		-- Video encoding options
		set videoCodec to ""
		set resolution to ""
		set videoBitrate to ""
		
		if encodeChoice is "Video Only" or encodeChoice is "Both" then
			-- Select video codec/format
			set codecChoice to choose from list {"H.264 (MP4)", "HEVC (H.265)", "VP9 (WebM)", "ProRes"} with title "Video Codec" with prompt "Select video codec/format:"
			
			if codecChoice is false then
				return
			end if
			
			set codecChoice to item 1 of codecChoice
			
			-- Set codec and container based on choice
			if codecChoice is "H.264 (MP4)" then
				set videoCodec to "libx264"
				set videoContainer to "mp4"
			else if codecChoice is "HEVC (H.265)" then
				set videoCodec to "libx265"
				set videoContainer to "mp4"
			else if codecChoice is "VP9 (WebM)" then
				set videoCodec to "libvpx-vp9"
				set videoContainer to "webm"
			else if codecChoice is "ProRes" then
				set videoCodec to "prores"
				set videoContainer to "mov"
			end if
			
			-- Select resolution
			set resolutionChoice to choose from list {"4K (2160p)", "1080p (Full HD)", "720p (HD)", "480p (SD)", "Custom"} with title "Resolution" with prompt "Select target resolution:"
			
			if resolutionChoice is false then
				return
			end if
			
			set resolutionChoice to item 1 of resolutionChoice
			
			if resolutionChoice is "4K (2160p)" then
				set resolution to "3840:2160"
			else if resolutionChoice is "1080p (Full HD)" then
				set resolution to "1920:1080"
			else if resolutionChoice is "720p (HD)" then
				set resolution to "1280:720"
			else if resolutionChoice is "480p (SD)" then
				set resolution to "854:480"
			else if resolutionChoice is "Custom" then
				display dialog "Enter custom resolution (e.g., 2560x1440):" default answer "1920x1080"
				set customRes to text returned of result
				set resolution to (text 1 thru ((offset of "x" in customRes) - 1) of customRes) & ":" & (text ((offset of "x" in customRes) + 1) thru -1 of customRes)
			end if
			
			-- Select video quality/bitrate
			set qualityChoice to choose from list {"Low (1500k)", "Medium (3000k)", "High (6000k)", "Very High (12000k)", "Custom"} with title "Video Quality" with prompt "Select video quality preset:"
			
			if qualityChoice is false then
				return
			end if
			
			set qualityChoice to item 1 of qualityChoice
			
			if qualityChoice is "Low (1500k)" then
				set videoBitrate to "1500k"
			else if qualityChoice is "Medium (3000k)" then
				set videoBitrate to "3000k"
			else if qualityChoice is "High (6000k)" then
				set videoBitrate to "6000k"
			else if qualityChoice is "Very High (12000k)" then
				set videoBitrate to "12000k"
			else if qualityChoice is "Custom" then
				display dialog "Enter custom bitrate (e.g., 5000k):" default answer "6000k"
				set videoBitrate to text returned of result
			end if
		end if
		
		-- Audio encoding options
		set audioCodec to ""
		set audioContainer to ""
		set audioBitrate to ""
		
		if encodeChoice is "Audio Only" or encodeChoice is "Both" then
			-- Select audio codec
			set audioCodecChoice to choose from list {"AAC (MP4)", "FLAC (Lossless)", "MP3", "Opus"} with title "Audio Codec" with prompt "Select audio codec:"
			
			if audioCodecChoice is false then
				return
			end if
			
			set audioCodecChoice to item 1 of audioCodecChoice			
			if audioCodecChoice is "AAC (MP4)" then
				set audioCodec to "aac"
				set audioContainer to "m4a"
			else if audioCodecChoice is "FLAC (Lossless)" then
				set audioCodec to "flac"
				set audioContainer to "flac"
			else if audioCodecChoice is "MP3" then
				set audioCodec to "libmp3lame"
				set audioContainer to "mp3"
			else if audioCodecChoice is "Opus" then
				set audioCodec to "libopus"
				set audioContainer to "opus"
			end if
			
			-- Select audio quality
			set audioQualityChoice to choose from list {"Low (128k)", "Medium (192k)", "High (320k)", "Lossless (FLAC)", "Custom"} with title "Audio Quality" with prompt "Select audio quality:"
			
			if audioQualityChoice is false then
				return
			end if
			
			set audioQualityChoice to item 1 of audioQualityChoice
			
			if audioQualityChoice is "Low (128k)" then
				set audioBitrate to "128k"
			else if audioQualityChoice is "Medium (192k)" then
				set audioBitrate to "192k"
			else if audioQualityChoice is "High (320k)" then
				set audioBitrate to "320k"
			else if audioQualityChoice is "Lossless (FLAC)" then
				set audioBitrate to ""
			else if audioQualityChoice is "Custom" then
				display dialog "Enter custom bitrate (e.g., 256k) or leave empty for lossless:" default answer "256k"
				set audioBitrate to text returned of result
			end if
		end if
		
		-- Get output directory
		set outputFolder to choose folder with prompt "Choose where to save the output file:"
		set outputFolderPath to POSIX path of outputFolder
		
		-- Generate output filename
		set timestamp to (do shell script "date +%Y%m%d_%H%M%S")
		
		if encodeChoice is "Video Only" then
			set defaultOutput to "video_reencoded_" & timestamp & "." & videoContainer
		else if encodeChoice is "Audio Only" then
			set defaultOutput to "audio_reencoded_" & timestamp & "." & audioContainer
		else
			set defaultOutput to "reencoded_" & timestamp & ".mkv"
		end if
		
		display dialog "Enter output filename:" default answer defaultOutput
		set outputFilename to text returned of result
		set outputPath to outputFolderPath & outputFilename
		
		-- Build ffmpeg command
		set ffmpegCommand to "ffmpeg"
		
		-- Input files
		if encodeChoice is "Video Only" then
			set ffmpegCommand to ffmpegCommand & " -i " & quoted form of videoPath
		else if encodeChoice is "Audio Only" then
			set ffmpegCommand to ffmpegCommand & " -i " & quoted form of audioPath
		else
			set ffmpegCommand to ffmpegCommand & " -i " & quoted form of videoPath & " -i " & quoted form of audioPath
		end if
		
		-- Video encoding options
		if encodeChoice is "Video Only" or encodeChoice is "Both" then
			set ffmpegCommand to ffmpegCommand & " -c:v " & videoCodec & " -b:v " & videoBitrate & " -s " & resolution
		end if
		
		-- Audio encoding options
		if encodeChoice is "Audio Only" then
			set ffmpegCommand to ffmpegCommand & " -c:a " & audioCodec
			if audioBitrate is not "" then
				set ffmpegCommand to ffmpegCommand & " -b:a " & audioBitrate
			end if
		else if encodeChoice is "Both" then
			set ffmpegCommand to ffmpegCommand & " -c:a " & audioCodec & " -map 0:v -map 1:a"
			if audioBitrate is not "" then
				set ffmpegCommand to ffmpegCommand & " -b:a " & audioBitrate
			end if
		end if
		
		set ffmpegCommand to ffmpegCommand & " " & quoted form of outputPath
		
		-- Show confirmation dialog with settings
		set summaryText to "Ready to re-encode:" & return & return
		
		if encodeChoice is "Video Only" then
			set summaryText to summaryText & "Video Input: " & videoPath & return
			set summaryText to summaryText & "Codec: " & codecChoice & return
			set summaryText to summaryText & "Resolution: " & resolution & return
			set summaryText to summaryText & "Bitrate: " & videoBitrate & return
		else if encodeChoice is "Audio Only" then
			set summaryText to summaryText & "Audio Input: " & audioPath & return
			set summaryText to summaryText & "Codec: " & audioCodecChoice & return
			set summaryText to summaryText & "Bitrate: " & audioBitrate & return
		else
			set summaryText to summaryText & "Video Input: " & videoPath & return
			set summaryText to summaryText & "Audio Input: " & audioPath & return
			set summaryText to summaryText & "Video Codec: " & codecChoice & return
			set summaryText to summaryText & "Resolution: " & resolution & return
			set summaryText to summaryText & "Video Bitrate: " & videoBitrate & return
			set summaryText to summaryText & "Audio Codec: " & audioCodecChoice & return
			set summaryText to summaryText & "Audio Bitrate: " & audioBitrate & return
		end if
		
		set summaryText to summaryText & return & "Output: " & outputPath
		
		display dialog summaryText buttons {"Cancel", "Re-encode"} default button 2
		
		if button returned of result is "Cancel" then
			return
		end if
		
		-- Run ffmpeg command in Terminal for progress feedback
		tell application "Terminal"
			activate
			do script ffmpegCommand
		end tell
		
		display notification "Re-encoding started! Check Terminal for progress." with title "Video/Audio Re-Encoder"
		
	on error errMsg number errNum
		display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
	end try
end run
