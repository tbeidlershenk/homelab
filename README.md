### Homelab

References & links for my homelab!

#### Setup

```bash
git clone https://github.com/tbeidlershenk/homelab.git && cd homelab

./scripts/prepare.sh
# Updates apt and sets up docker
```

#### Backups

```bash
./scripts/backup.sh
# Generates a backup of docker volumes, defaulting to drive mounted at /mnt/backup

./scripts/restore.sh
# Restores docker volumes from a backup. Defaults to the latest backup in /mnt/backup
```

#### Maintenance

```bash
./scripts/start-services.sh
# Starts all services defined in services/

./scripts/stop-services
# Gracefully stops all services

./scripts/clean-docker.sh
# Cleans docker system of active volumes, containers, etc.


```
