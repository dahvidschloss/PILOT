import socket
import struct
import os

def listen_for_data():
    # Create a raw socket to listen for ICMP packets cause f scappy we don't need that shit
    icmp = socket.getprotobyname('icmp')
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, icmp)
    
    print("Listening for incoming ICMP packets...")
    file_data = b''
    file_name = ''
    file_extension = ''
    total_chunks = 0
    received_chunks = 0

    try:
        while True:
            packet, addr = sock.recvfrom(1024)
            # ICMP packet parsing would be more complex in a real scenario
            # This assumes data starts at byte 28
            data = packet[28:]
            
            if received_chunks == 0:
                # First packet with file data.
                metadata_str = data.decode('ascii').strip('\x00')
                print(f"Received metadata: {metadata_str}")
                metadata_parts = metadata_str.split('\n')
                file_name = metadata_parts[0].split(': ')[1]
                file_extension = metadata_parts[1].split(': ')[1]
                total_chunks = int(metadata_parts[2].split(': ')[1])
            else:
                # Subsequent packets with file data
                file_data += data
                print(f"Received chunk {received_chunks} of {total_chunks}")
            
            received_chunks += 1
            
            if received_chunks > total_chunks:
                break
    finally:
        sock.close()
    
    return file_name + file_extension, file_data

def save_file(filename, data):
    with open(filename, 'wb') as f:
        f.write(data)
    print(f"File {filename} saved successfully.")

if __name__ == '__main__':
    filename, data = listen_for_data()
    save_file(filename, data)
