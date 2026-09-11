import json
from flask import Blueprint, Response, jsonify, request
import requests
from dotenv import load_dotenv
from logger import logger
import os
import sys
from wakeonlan import wake
from time import sleep

tasks = Blueprint("tasks", __name__)

macos_hostname = os.getenv("MACOS_HOSTNAME")
macos_mac_address = os.getenv("MACOS_MAC_ADDRESS")
macos_port = os.getenv("MACOS_OTP_SERVER_PORT")

if macos_hostname is None:
    print("MACOS_HOSTNAME not defined.")
    sys.exit(1)
if macos_hostname is None:
    print("MACOS_MAC_ADDRESS not defined.")
    sys.exit(1)
if macos_port is None:
    print("MACOS_OTP_SERVER_PORT not defined.")
    sys.exit(1)

macos_url = f'http://{macos_hostname}:{macos_port}'

@tasks.route("/get", methods=["GET"])
async def get():
    # send WOL packet
    wake(macos_mac_address)
    logger.info(f"Sent WOL packet to {macos_mac_address}")

    # wait a bit
    sleep(1)

    # put mac in a more awake state
    resp = requests.get(f'{macos_url}/caffeinate')
    resp.raise_for_status()
    logger.info(f"Sent /caffeinate request to {macos_hostname}")

    # wait a bit
    sleep(1)

    # get otp code
    resp = requests.get(f'{macos_url}/otps?count=1')
    resp.raise_for_status()
    data = resp.json()
    logger.info(f"Retreived {len(data)} codes from {macos_hostname}")

    return jsonify(data), 200