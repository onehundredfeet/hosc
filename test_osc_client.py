#!/usr/bin/env python3
"""
OSC Client for testing the Haxe OSC Server
Requires python-osc: pip install python-osc
"""

import argparse
import time
import struct
import socket
from pythonosc import udp_client
from pythonosc.osc_message_builder import OscMessageBuilder
from pythonosc.osc_message import OscMessage

class OSCTestClient:
    def __init__(self, host="127.0.0.1", port=8000):
        self.host = host
        self.port = port
        self.client = udp_client.SimpleUDPClient(host, port)
        
    def send_message(self, address, *args):
        """Send an OSC message and return True if successful"""
        try:
            self.client.send_message(address, args if args else None)
            print(f"✓ Sent: {address} {args}")
            return True
        except Exception as e:
            print(f"✗ Error sending {address}: {e}")
            return False
    
    def send_raw_osc(self, address, type_tags, *args):
        """Send a raw OSC message for testing parser robustness"""
        try:
            # Build OSC message manually
            message = OscMessageBuilder(address)
            for i, arg in enumerate(args):
                if i < len(type_tags):
                    tag = type_tags[i]
                    if tag == 'i':
                        message.add_arg(int(arg))
                    elif tag == 'f':
                        message.add_arg(float(arg))
                    elif tag == 's':
                        message.add_arg(str(arg))
                    elif tag == 'b':
                        message.add_arg(bytes(arg, 'utf-8') if isinstance(arg, str) else arg)
            
            msg = message.build()
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.sendto(msg.dgram, (self.host, self.port))
            sock.close()
            print(f"✓ Sent raw: {address} ({type_tags}) {args}")
            return True
        except Exception as e:
            print(f"✗ Error sending raw {address}: {e}")
            return False

def run_basic_tests(client):
    """Run basic functionality tests"""
    print("\n=== Basic OSC Tests ===")
    
    # Test ping
    client.send_message("/ping")
    time.sleep(0.1)
    
    # Test echo with different data types
    client.send_message("/echo", 42)
    client.send_message("/echo", 3.14159)
    client.send_message("/echo", "hello world")
    client.send_message("/echo", 123, 45.67, "mixed")
    time.sleep(0.1)
    
    # Test info
    client.send_message("/info")
    time.sleep(0.1)
    
    # Test math
    client.send_message("/math/add", 10, 15)
    client.send_message("/math/add", 100, 200)
    time.sleep(0.1)

def run_custom_handler_tests(client):
    """Test the custom handlers defined in Main.hx"""
    print("\n=== Custom Handler Tests ===")
    
    # Audio volume tests
    client.send_message("/audio/volume", 0.75)
    client.send_message("/audio/volume", 50)  # Should convert from int
    client.send_message("/audio/volume", 1.5)  # Should clamp to 1.0
    client.send_message("/audio/volume")       # Should error - no args
    time.sleep(0.1)
    
    # MIDI note tests
    client.send_message("/midi/note", 60, 127)
    client.send_message("/midi/note", 72, 100)
    client.send_message("/midi/note", 48.5, 80.2)  # Should convert floats
    client.send_message("/midi/note", 60)           # Should error - not enough args
    time.sleep(0.1)
    
    # Parameter control tests
    client.send_message("/control/param", "filter_cutoff", 1000.0)
    client.send_message("/control/param", "reverb_mix", 0.3)
    client.send_message("/control/param", "delay_time", 500)
    client.send_message("/control/param")  # Should error - no args
    time.sleep(0.1)

def run_edge_case_tests(client):
    """Test edge cases and error conditions"""
    print("\n=== Edge Case Tests ===")
    
    # Test unknown addresses
    client.send_message("/unknown/address")
    client.send_message("/test/nonexistent", 1, 2, 3)
    time.sleep(0.1)
    
    # Test empty messages
    client.send_message("/ping")
    time.sleep(0.1)
    
    # Test large numbers
    client.send_message("/math/add", 999999, 1)
    client.send_message("/math/add", -500, 600)
    time.sleep(0.1)
    
    # Test very long strings
    long_string = "A" * 100
    client.send_message("/echo", long_string)
    time.sleep(0.1)
    
    # Test special characters
    client.send_message("/echo", "Hello 世界! 🎵")
    time.sleep(0.1)

def run_type_tests(client):
    """Test different OSC data types"""
    print("\n=== Data Type Tests ===")
    
    # Integer tests
    client.send_raw_osc("/echo", "i", 42)
    client.send_raw_osc("/echo", "i", -1000)
    client.send_raw_osc("/echo", "i", 0)
    
    # Float tests  
    client.send_raw_osc("/echo", "f", 3.14159)
    client.send_raw_osc("/echo", "f", -999.999)
    client.send_raw_osc("/echo", "f", 0.0)
    
    # String tests
    client.send_raw_osc("/echo", "s", "simple string")
    client.send_raw_osc("/echo", "s", "")
    
    # Mixed type tests
    client.send_raw_osc("/echo", "ifs", 123, 45.67, "mixed")
    client.send_raw_osc("/echo", "sif", "first", 456, 78.90)
    
    time.sleep(0.1)

def run_stress_tests(client):
    """Run stress tests with rapid messages"""
    print("\n=== Stress Tests ===")
    
    print("Sending rapid ping messages...")
    start_time = time.time()
    for i in range(50):
        client.send_message("/ping")
        time.sleep(0.01)  # 10ms between messages
    
    elapsed = time.time() - start_time
    print(f"Sent 50 messages in {elapsed:.2f}s ({50/elapsed:.1f} msg/s)")
    
    print("Sending batch of mixed messages...")
    for i in range(20):
        client.send_message("/math/add", i, i*2)
        client.send_message("/audio/volume", i/20.0)
        client.send_message("/echo", f"message_{i}")
        time.sleep(0.005)
    
    time.sleep(0.1)

def main():
    parser = argparse.ArgumentParser(description="Test OSC Server")
    parser.add_argument("--host", default="127.0.0.1", help="OSC server host")
    parser.add_argument("--port", type=int, default=8000, help="OSC server port")
    parser.add_argument("--test", choices=["basic", "custom", "edge", "types", "stress", "all"], 
                       default="all", help="Test suite to run")
    
    args = parser.parse_args()
    
    print(f"Testing OSC server at {args.host}:{args.port}")
    print("Make sure the Haxe OSC server is running!")
    print("-" * 50)
    
    client = OSCTestClient(args.host, args.port)
    
    if args.test in ["basic", "all"]:
        run_basic_tests(client)
    
    if args.test in ["custom", "all"]:
        run_custom_handler_tests(client)
    
    if args.test in ["edge", "all"]:
        run_edge_case_tests(client)
    
    if args.test in ["types", "all"]:
        run_type_tests(client)
    
    if args.test in ["stress", "all"]:
        run_stress_tests(client)
    
    # Test shutdown (commented out by default)
    print("\n=== Shutdown Test (commented out) ===")
    print("To test shutdown, uncomment the line below:")
    print("# client.send_message('/system/shutdown')")
    # client.send_message("/system/shutdown")
    
    print("\n=== Testing Complete ===")

if __name__ == "__main__":
    main()
