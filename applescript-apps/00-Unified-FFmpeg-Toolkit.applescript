-- Unified FFmpeg Toolkit
-- Combines the logic of all five AppleScript utilities into a single app

on run
    try
        set appsList to {"Movie Sync Audio", "FFmpeg Info Logger", "FLAC Combiner", "Test Clip Extractor", "Transcode Final Product"}
        set chosen to choose from list appsList with prompt "Choose a tool to run:" default items {item 1 of appsList}
        if chosen is false then return
        set selectedTool to item 1 of chosen
        if selectedTool is "Movie Sync Audio" then
            my movieSyncAudio()
        else if selectedTool is "FFmpeg Info Logger" then
            my ffmpegInfoLogger()
        else if selectedTool is "FLAC Combiner" then
            my flacCombiner()
        else if selectedTool is "Test Clip Extractor" then
            my testClipExtractor()
        else if selectedTool is "Transcode Final Product" then
            my transcodeFinalProduct()
        end if
    on error errMsg number errNum
        display dialog "Error: " & errMsg buttons {"OK"} default button 1 with icon caution
    end try
end run

on movieSyncAudio()
    set videoFile to choose file with prompt "Select the video file (MKV or MP4):" of type {"mp4", "mkv", "mov"}
    set videoPath to POSIX path of videoFile
    set audioFile to choose file with prompt "Select the audio file (FLAC or MP3):" of type {"mp3", "flac", "wav", "m4a"}
    set audioPath to POSIX path of audioFile
    display dialog "Enter audio delay in milliseconds (default: 36000ms = 36 seconds):" default answer "36000"
    set audioDelay to text returned of result
    try
        set audioDelay to audioDelay as integer
    on error
        display dialog "Error: Audio delay must be a number!" buttons {"OK"} default button 1 with icon caution
        return
    end try
    set defaultOutput to "SyncedOutput.mkv"
    display dialog "Enter output filename:" default answer defaultOutput
    set outputFilename to text returned of result
    set outputFolder to choose folder with prompt "Choose where to save the output file:"
    set outputPath to (POSIX path of outputFolder) & outputFilename
    set ffmpegCommand to "ffmpeg -i " & quoted form of videoPath & " -stream_loop -1 -i " & quoted form of audioPath & " -filter_complex \"[1:a]adelay=" & audioDelay & "|" & audioDelay & ",apad[aud]\" -map 0:v -map \"[aud]\" -c:v copy -c:a flac -shortest " & quoted form of outputPath
    display dialog "Ready to process:" & return & return & "Video: " & videoPath & return & "Audio: " & audioPath & return & "Delay: " & audioDelay & "ms" & return & "Output: " & outputPath buttons {"Cancel", "Process"} default button 2
    if button returned of result is "Cancel" then return
    tell application "Terminal"
        activate
        do script ffmpegCommand
    end tell
    display notification "Processing started! Check Terminal for progress." with title "Movie Sync Audio"
end movieSyncAudio

on ffmpegInfoLogger()
    set mediaFile to choose file with prompt "Select media file (MKV, MP4, FLAC, etc):" of type {"public.video", "public.audio"}
    set mediaPath to POSIX path of mediaFile
    set fileInfo to info for mediaFile
    set fileName to name of fileInfo
    set extensionText to name extension of fileInfo
    if extensionText is missing value then
        set baseName to fileName
    else
        set baseName to text 1 thru ((length of fileName) - (length of extensionText) - 1) of fileName
    end if
    set outputFolder to choose folder with prompt "Choose where to save the log file:"
    set logPath to (POSIX path of outputFolder) & baseName & "_ffmpeg_log.txt"
    display dialog "Ready to analyze:" & return & return & "File: " & mediaPath & return & "Output: " & logPath buttons {"Cancel", "Analyze"} default button 2
    if button returned of result is "Cancel" then return
    set ffmpegCommand to "ffmpeg -i " & quoted form of mediaPath & " -f null - > " & quoted form of logPath & " 2>&1"
    tell application "Terminal"
        activate
        do script ffmpegCommand
    end tell
    display notification "Analysis started! Check Terminal for progress." with title "FFmpeg Info Logger"
end ffmpegInfoLogger

on flacCombiner()
    set flacFiles to choose file with prompt "Select FLAC files to combine (select one or multiple):" of type {"public.audio"} with multiple selections allowed
    if (count of flacFiles) < 2 then
        display dialog "Error: You must select at least 2 files!" buttons {"OK"} default button 1 with icon caution
        return
    end if
    set outputFolder to choose folder with prompt "Choose where to save the combined file:"
    display dialog "Enter output filename:" default answer "Combined.flac"
    set outputFilename to text returned of result
    set outputPath to (POSIX path of outputFolder) & outputFilename
    set concatListPath to (POSIX path of outputFolder) & "flac_list.txt"
    set concatContent to ""
    repeat with flacFile in flacFiles
        set flacPath to POSIX path of flacFile
        set concatContent to concatContent & "file '" & flacPath & "'" & linefeed
    end repeat
    set fileHandle to open for access concatListPath with write permission
    set eof fileHandle to 0
    write concatContent to fileHandle
    close access fileHandle
    display dialog "Ready to combine " & (count of flacFiles) & " FLAC files:" & return & return & "Output: " & outputPath & return & return & "Concat list: " & concatListPath buttons {"Cancel", "Combine"} default button 2
    if button returned of result is "Cancel" then return
    set ffmpegCommand to "ffmpeg -y -f concat -safe 0 -i " & quoted form of concatListPath & " -c:a flac " & quoted form of outputPath
    tell application "Terminal"
        activate
        do script ffmpegCommand
    end tell
    display notification "FLAC combination started! Check Terminal for progress." with title "FLAC Combiner"
end flacCombiner

on testClipExtractor()
    set videoFile to choose file with prompt "Select the video file (MKV or MP4):" of type {"mp4", "mkv", "mov"}
    set videoPath to POSIX path of videoFile
    set audioFile to choose file with prompt "Select the audio file (FLAC or MP3):" of type {"mp3", "flac", "wav", "m4a"}
    set audioPath to POSIX path of audioFile
    display dialog "Extract first how many minutes? (default: 3):" default answer "3"
    set durationMinutes to text returned of result
    try
        set durationMinutes to durationMinutes as integer
    on error
        display dialog "Error: Duration must be a number!" buttons {"OK"} default button 1 with icon caution
        return
    end try
    set durationSeconds to durationMinutes * 60
    display dialog "Enter audio delay in milliseconds (default: 36000ms = 36 seconds):" default answer "36000"
    set audioDelay to text returned of result
    try
        set audioDelay to audioDelay as integer
    on error
        display dialog "Error: Audio delay must be a number!" buttons {"OK"} default button 1 with icon caution
        return
    end try
    set defaultOutput to "TEST_" & durationMinutes & "min.mkv"
    display dialog "Enter output filename:" default answer defaultOutput
    set outputFilename to text returned of result
    set outputFolder to choose folder with prompt "Choose where to save the test clip:"
    set outputPath to (POSIX path of outputFolder) & outputFilename
    set ffmpegCommand to "ffmpeg -ss 0 -i " & quoted form of videoPath & " -stream_loop -1 -i " & quoted form of audioPath & " -t " & durationSeconds & " -filter_complex \"[1:a]adelay=" & audioDelay & "|" & audioDelay & ",apad[aud]\" -map 0:v -map \"[aud]\" -c:v copy -c:a flac " & quoted form of outputPath
    display dialog "Ready to extract test clip:" & return & return & "Video: " & videoPath & return & "Audio: " & audioPath & return & "Duration: " & durationMinutes & " minutes" & return & "Audio Delay: " & audioDelay & "ms" & return & "Output: " & outputPath buttons {"Cancel", "Extract"} default button 2
    if button returned of result is "Cancel" then return
    tell application "Terminal"
        activate
        do script ffmpegCommand
    end tell
    display notification "Test clip extraction started! Check Terminal for progress." with title "Test Clip Extractor"
end testClipExtractor

on transcodeFinalProduct()
    set inputFile to choose file with prompt "Select the input video file:" of type {"mp4", "mkv", "mov", "m4v"}
    set inputPath to POSIX path of inputFile
    set containerOptions to {"mp4", "mkv", "mov"}
    set chosenContainer to choose from list containerOptions with prompt "Choose output container:" default items {"mp4"}
    if chosenContainer is false then return
    set container to item 1 of chosenContainer
    set vcodecOptions to {"copy (preserve original)", "libx264 (H.264)", "libx265 (HEVC)"}
    set chosenVcodec to choose from list vcodecOptions with prompt "Choose video codec:" default items {"libx265 (HEVC)"}
    if chosenVcodec is false then return
    set vcodecChoice to item 1 of chosenVcodec
    set resOptions to {"Original", "1080p (1920x1080)", "720p (1280x720)", "480p (854x480)", "Custom (enter height)"}
    set chosenRes to choose from list resOptions with prompt "Choose resolution:" default items {"Original"}
    if chosenRes is false then return
    set resChoice to item 1 of chosenRes
    if resChoice is "Custom (enter height)" then
        display dialog "Enter desired output height in pixels (e.g. 1080):" default answer "1080"
        set outHeight to text returned of result
        try
            set outHeight to outHeight as integer
        on error
            display dialog "Invalid number for height." buttons {"OK"} default button 1 with icon caution
            return
        end try
        set scaleFilter to "scale=-2:" & outHeight
    else if resChoice is "Original" then
        set scaleFilter to ""
    else if resChoice contains "1080" then
        set scaleFilter to "scale=-2:1080"
    else if resChoice contains "720" then
        set scaleFilter to "scale=-2:720"
    else if resChoice contains "480" then
        set scaleFilter to "scale=-2:480"
    else
        set scaleFilter to ""
    end if
    set aOptions to {"copy (preserve original)", "AAC (lossy, 320k)", "ALAC (lossless)", "FLAC (lossless)"}
    set chosenA to choose from list aOptions with prompt "Choose audio option:" default items {"copy (preserve original)"}
    if chosenA is false then return
    set aChoice to item 1 of chosenA
    set defaultName to "TranscodedOutput." & container
    display dialog "Enter output filename:" default answer defaultName
    set outputFilename to text returned of result
    set outputFolder to choose folder with prompt "Choose where to save the output file:"
    set outputPath to (POSIX path of outputFolder) & outputFilename
    if vcodecChoice starts with "copy" and scaleFilter is not "" then
        display dialog "You requested video copy but also a resolution change. Video will be re-encoded with libx264. Continue?" buttons {"Cancel", "Continue"} default button 2
        if button returned of result is "Cancel" then return
        set vcodecChoice to "libx264 (H.264)"
    end if
    if vcodecChoice starts with "copy" then
        set vcodecCmd to "-c:v copy"
    else if vcodecChoice contains "libx264" then
        set vcodecCmd to "-c:v libx264 -preset slow -crf 18"
    else if vcodecChoice contains "libx265" then
        set vcodecCmd to "-c:v libx265 -preset slow -crf 22"
    else
        set vcodecCmd to "-c:v libx265 -preset slow -crf 22"
    end if
    if aChoice starts with "copy" then
        set acmd to "-c:a copy"
    else if aChoice contains "AAC" then
        set acmd to "-c:a aac -b:a 320k"
    else if aChoice contains "ALAC" then
        set acmd to "-c:a alac"
    else if aChoice contains "FLAC" then
        set acmd to "-c:a flac"
    else
        set acmd to "-c:a copy"
    end if
    if scaleFilter is not "" then
        set vfPart to "-vf \"" & scaleFilter & "\""
    else
        set vfPart to ""
    end if
    set ffmpegCommand to "ffmpeg -i " & quoted form of inputPath & " " & vfPart & " " & vcodecCmd & " " & acmd & " -movflags +faststart " & quoted form of outputPath
    display dialog "Ready to transcode with the following settings:" & return & return & "Input: " & inputPath & return & "Output: " & outputPath & return & "Video codec: " & vcodecChoice & return & "Audio: " & aChoice buttons {"Cancel", "Process"} default button 2
    if button returned of result is "Cancel" then return
    tell application "Terminal"
        activate
        do script ffmpegCommand
    end tell
    display notification "Transcoding started — check Terminal for progress." with title "Transcode Final Product"
end transcodeFinalProduct
