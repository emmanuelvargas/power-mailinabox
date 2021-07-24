#!/usr/local/lib/mailinabox/env/bin/python

import socket
import time

def validate_ip(addr):
    try:
        socket.inet_aton(addr)
        return True
    except socket.error:
        return False

if __name__ == "__main__":
	import sys
	if len(sys.argv) > 2 and sys.argv[1] == "validate-ip":
		# Validate that the ip is a valid one
		if validate_ip(sys.argv[2]):
			#print("GOOD")
			#time.sleep(5)
			sys.exit(0)
		else:
			#print("NO GOOD")
			#time.sleep(5)
			sys.exit(1)
