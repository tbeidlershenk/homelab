from flask import Flask, jsonify
from dotenv import load_dotenv
import subprocess
from routes.tasks import tasks
import json

server = Flask(__name__)

load_dotenv()

server.register_blueprint(tasks, url_prefix="/tasks")
server.config["JSONIFY_PRETTYPRINT_REGULAR"] = True


@server.route("/")
def home():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    server.run(host="0.0.0.0", port=5000, debug=True, threaded=True)
