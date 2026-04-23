# Python script to hit api task endpoint
#
# Endpoint will run a chosen script from scripts/
# Endpoint will send back logs via SSE
#   1. Endpoint will log the script stdout to file
#   2. Separate thread will return stdout as SSE
#
# Script will be run in Cronicle
#   1. Returns { "complete": 1, "code": 0 } on success
#   2. Returns { "complete": 1, "code": 1 } on failure

import sys
import os

print("Python task endpoint")
print(os.getenv("YEAR"))
print('{ "complete": 1, "code": 0 }')
