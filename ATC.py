import socket


def listen_for_data():
    # Create a raw socket to listen for ICMP packets cause f scappy we don't need that shit
    icmp = socket.getprotobyname('icmp')
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, icmp)
    
    print("Listening for incoming ICMP packets...")
    file_data = bytearray()
    file_name = ''
    total_chunks = 0
    received_chunks = 0

    try:
        while True:
            packet, addr = sock.recvfrom(65535)
            #if less than 28 not real
            if len(packet) < 28:
                continue
            #if packet isn't the proper length of an IMCP header then we can ignore too
            ip_header_len = (packet[0] & 0x0F) * 4
            if ip_header_len < 20 or len(packet) < ip_header_len + 8 or packet[ip_header_len] != 8:
                continue
            data = packet[ip_header_len + 8:]
            
            if received_chunks == 0:
                try:
                    metadata_str = data.decode('ascii').strip('\x00')
                    metadata_parts = metadata_str.split('\n')
                    if (len(metadata_parts) != 3
                            or not metadata_parts[0].startswith('FileName: ')
                            or not metadata_parts[1].startswith('FileType: ')
                            or not metadata_parts[2].startswith('TotalChunks: ')):
                        continue

                    file_name = metadata_parts[0].split(': ', 1)[1]
                    total_chunks = int(metadata_parts[2].split(': ', 1)[1])
                except (UnicodeDecodeError, ValueError):
                    continue

                print(f"Received metadata: {metadata_str}")
                
            else:
                # Subsequent packets with file data
                file_data.extend(data)  
                print(f"Received chunk {received_chunks} of {total_chunks}")
            
            received_chunks += 1
            
            if received_chunks > total_chunks:
                break
    finally:
        sock.close()
    
    return file_name, bytes(file_data)

def save_file(filename, data):
    with open(filename, 'wb') as f:
        f.write(data)
    print(f"File {filename} saved successfully.")

if __name__ == '__main__':
    filename, data = listen_for_data()
    save_file(filename, data)
