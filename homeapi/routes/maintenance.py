import json
from flask import Blueprint, Response, jsonify, request
from dotenv import load_dotenv
from logger import logger
import os
import sys
import subprocess
import jsonschema
import asyncio

maintenance = Blueprint('maintenance', __name__)

base_dir = os.getenv('BASE_DIR')
if not os.path.exists(base_dir):
    print("BASE_DIR not defined or does not exist.")
    sys.exit(1)

scripts_dir = base_dir + '/scripts'

@maintenance.route('/backup', methods=['GET'])
async def backup():
    script_path = os.path.join(scripts_dir, 'backup.sh')
    try:
        process = await asyncio.create_subprocess_exec(
            'bash', script_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        stdout = stdout.decode()
        stderr = stderr.decode()
        logger.info(f"maintenance/backup returned status {process.returncode}")
        return Response(stdout, mimetype='text/plain'), 200
    except:
        process.kill()
        stdout, stderr = await process.communicate()
        return Response(stdout, mimetype='text/plain'), 500

@maintenance.route('/restart', methods=['GET'])
async def restart():
    script_path = os.path.join(scripts_dir, 'restart.sh')
    try:
        process = await asyncio.create_subprocess_exec(
            'bash', script_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        stdout = stdout.decode()
        stderr = stderr.decode()
        logger.info(f"maintenance/restart returned status {process.returncode}")
        return Response(stdout, mimetype='text/plain'), 200
    except:
        process.kill()
        stdout, stderr = await process.communicate()
        return Response(stdout, mimetype='text/plain'), 500

# @maintenance.route('/update_registry', methods=['GET'])
# def update_registry():
#     script_path = os.path.join(scripts_dir, 'update_registry.sh')
#     data = request.get_json()
#     schema_path = os.path.join(base_dir, 'registry_schema.json')
#     with open(schema_path, 'r') as f:
#         schema = json.load(f)
#     jsonschema.validate(instance=data, schema=schema)
#     result = subprocess.run(['bash', script_path])
#     logger.info(f"maintenance/update_registry returned status {result.returncode}")
#     return result.returncode

# @maintenance.route('/restore', methods=['GET'])
# def restore():
#     script_path = os.path.join(scripts_dir, 'restore.sh')
#     result = subprocess.run(['bash', script_path])
#     logger.info(f"Restore returned status {result.returncode}")
#     return jsonify({'result': result.returncode}), 200
