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
import requests
from sseclient import SSEClient

task = sys.argv[1]
url = f"http://localhost:5001/tasks/run/{task}"
messages = SSEClient(url)

for msg in messages:
    print(f"[{msg.event}] {msg.data}")

    if msg.event == "done":
        result = {"complete": 1, "code": {msg.data}}
        print(str(result))
        break
