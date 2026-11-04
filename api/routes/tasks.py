from flask import Blueprint, Response, abort, jsonify
from logger import logger
import os
import re
import sys
import subprocess
import selectors
import traceback
import signal

tasks = Blueprint("tasks", __name__)

base_dir = os.getenv("BASE_DIR")
if not base_dir or not os.path.isdir(base_dir):
    print("BASE_DIR not defined or does not exist.")
    sys.exit(1)

scripts_dir = os.path.realpath(os.path.join(base_dir, "scripts"))

# Script names are plain identifiers: no slashes, dots, or shell metacharacters.
SCRIPT_NAME_RE = re.compile(r"^[A-Za-z0-9_-]+$")


def resolve_script(script_name: str) -> str:
    """Map a URL script name to scripts/<name>.sh, or abort with 404.

    Rejects anything that isn't a plain name and anything whose resolved
    path (after following symlinks) lands outside scripts_dir.
    """
    if not SCRIPT_NAME_RE.fullmatch(script_name):
        abort(404)
    path = os.path.realpath(os.path.join(scripts_dir, f"{script_name}.sh"))
    if os.path.dirname(path) != scripts_dir or not os.path.isfile(path):
        abort(404)
    return path


def stream_process(script_path: str):
    process = subprocess.Popen(
        ["bash", script_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )

    try:
        # Send PID immediately
        yield f"event: pid\ndata: {process.pid}\n\n"

        sel = selectors.DefaultSelector()
        sel.register(process.stdout, selectors.EVENT_READ)
        sel.register(process.stderr, selectors.EVENT_READ)

        while True:
            for key, _ in sel.select():
                line = key.fileobj.readline()

                if not line:
                    sel.unregister(key.fileobj)
                    continue

                if key.fileobj is process.stdout:
                    yield f"event: stdout\ndata: {line.rstrip()}\n\n"
                else:
                    yield f"event: stderr\ndata: {line.rstrip()}\n\n"

            if not sel.get_map():
                break

        process.wait()
        yield f"event: done\ndata: {process.returncode}\n\n"

    except GeneratorExit:
        try:
            pgrp = os.getpgid(process.pid)
            os.killpg(pgrp, signal.SIGINT)
        except Exception:
            traceback.print_exc()
            pass
        raise

    finally:
        try:
            if process.poll() is None:
                pgrp = os.getpgid(process.pid)
                os.killpg(pgrp, signal.SIGINT)
                logger.info(f"Killing process group under {process.pid}")
        except Exception:
            traceback.print_exc()
            pass

        if process.stdout:
            process.stdout.close()
        if process.stderr:
            process.stderr.close()


@tasks.route("/run/<script_name>", methods=["GET"])
async def run_task(script_name: str):
    script_path = resolve_script(script_name)
    return Response(
        stream_process(script_path),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@tasks.route("/run_unattended/<script_name>", methods=["GET"])
async def run_task_unattended(script_name: str):
    script_path = resolve_script(script_name)
    process = subprocess.Popen(
        ["bash", script_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return jsonify({"status": "started", "pid": process.pid})
