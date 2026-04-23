import json
from flask import Blueprint, Response, jsonify, request
from dotenv import load_dotenv
from logger import logger
import os
import sys
import subprocess
import jsonschema
import asyncio

maintenance = Blueprint("maintenance", __name__)

base_dir = os.getenv("BASE_DIR")
if not os.path.exists(base_dir):
    print("BASE_DIR not defined or does not exist.")
    sys.exit(1)

scripts_dir = base_dir + "/scripts"


def safe_read(path, default=None):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        return default
    except Exception as e:
        return str(e)


@maintenance.route("/status", methods=["GET"])
async def status():
    version = safe_read("/tmp/deploy_version", "unknown")
    status = safe_read("/tmp/deploy_status", "unknown")
    return {"status": status, "version": version}


@maintenance.route("/backup", methods=["GET"])
async def backup():
    script_path = os.path.join(scripts_dir, "backup.sh")
    try:
        process = await asyncio.create_subprocess_exec(
            "bash",
            script_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await process.communicate()
        stdout = stdout.decode()
        stderr = stderr.decode()
        logger.info(f"maintenance/backup returned status {process.returncode}")
        return Response(stdout, mimetype="text/plain"), 200
    except:
        process.kill()
        stdout, stderr = await process.communicate()
        return Response(stdout, mimetype="text/plain"), 500
