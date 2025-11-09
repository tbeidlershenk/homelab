from flask import Flask, jsonify
from dotenv import load_dotenv
import subprocess
from routes.maintenance import maintenance

server = Flask(__name__)

load_dotenv()

server.register_blueprint(maintenance, url_prefix="/maintenance")
server.config["JSONIFY_PRETTYPRINT_REGULAR"] = True

@server.route('/')
def home():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    server.run(host='0.0.0.0', port=5000, debug=True)