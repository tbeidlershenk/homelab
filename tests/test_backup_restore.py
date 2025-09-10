import subprocess
import os
import pytest
import dotenv

dotenv.load_dotenv()
backup_dir = "/tmp/backup"
volumes_dir = f"{os.environ['HOME']}/homelab/volumes"
scripts_dir = f"{os.environ['HOME']}/homelab/scripts"

@pytest.fixture(autouse=True)
def setup_and_teardown(tmp_path):
    # Example: Clean up or set up environment before each test
    # You can create temp dirs, set env vars, etc.
    yield
    # Teardown code (if needed) runs after each test

def test_backup_and_restore():
    # Start services
    result = subprocess.run(["bash", f"{scripts_dir}/start-services.sh"], capture_output=True, text=True)
    assert result.returncode == 0
    assert os.path.exists(volumes_dir)
    volumes_list = os.listdir(volumes_dir)
    assert volumes_list

    # Do backup
    result = subprocess.run(["bash", f"{scripts_dir}/backup.sh", backup_dir], capture_output=True, text=True)
    assert result.returncode == 0
    assert os.path.exists(backup_dir)
    assert os.listdir(backup_dir)

    # Do restore
    result = subprocess.run(["bash", f"{scripts_dir}/restore.sh", backup_dir], capture_output=True, text=True)
    assert result.returncode == 0
    assert os.path.exists(volumes_dir)
    volumes_list_after_restore = os.listdir(volumes_dir)
    assert os.listdir(volumes_dir)
    assert volumes_list == volumes_list_after_restore
