TASK 1

sudo groupadd sysadm
sudo groupadd dbops

sudo vi /etc/sudoers.d/sysadm

%sysadm ALL=(ALL) NOPASSWD: /bin/systemctl

sudo chmod 440 /etc/sudoers.d/sysadm
sudo cp /etc/sudoers.d/sysadm /home/kbtu/sysadm.bak

sudo vi /etc/sudoers.d/dbops

%dbops ALL=(ALL) NOPASSWD: /usr/bin/podman exec mysql *

sudo chmod 440 /etc/sudoers.d/dbops
sudo cp /etc/sudoers.d/dbops /home/kbtu/dbops.bak

TASK 2

sudo mkdir -p /var/db/mysql-data /var/backups/mysql
sudo chown 999:999 /var/db/mysql-data
sudo chmod 700 /var/db/mysql-data

sudo vi /usr/local/bin/backup-mysql.sh

#!/bin/bash
BACKUP_DIR=/var/backups/mysql
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
sudo podman exec mysql mysqldump -u root -pStrongPassword123 --all-databases > "$BACKUP_DIR/backup-${TIMESTAMP}.sql"
echo "Backup done"

sudo chmod 750 /usr/local/bin/backup-mysql.sh
sudo chown root:sysadm /usr/local/bin/backup-mysql.sh
sudo cp /usr/local/bin/backup-mysql.sh /home/kbtu/backup-mysql.sh

sudo vi /etc/cron.d/mysql-backup

0 2 * * * root /usr/local/bin/backup-mysql.sh

sudo cp /etc/cron.d/mysql-backup /home/kbtu/mysql-backup.bak

sudo vi /etc/audit/rules.d/mysql-backup.rules

-w /usr/local/bin/backup-mysql.sh -p wa -k mysql-backup-tamper
-w /etc/cron.d/mysql-backup -p wa -k mysql-backup-tamper

sudo cp /etc/audit/rules.d/mysql-backup.rules /home/kbtu/mysql-backup.rules
sudo augenrules --load
sudo systemctl enable --now auditd

TASK 3

sudo podman run -d \
  --name mysql \
  --network host \
  --memory 512m \
  --memory-swap 512m \
  --cpus 1.0 \
  -v /var/db/mysql-data:/var/lib/mysql:Z \
  -e MYSQL_ROOT_PASSWORD=StrongPassword123 \
  docker.io/library/mysql:latest

sudo vi /etc/systemd/system/container-mysql.service

[Unit]
Description=MySQL Container
After=network.target

[Service]
Restart=always
ExecStart=/usr/bin/podman start -a mysql
ExecStop=/usr/bin/podman stop mysql

[Install]
WantedBy=multi-user.target
Bash
sudo cp /etc/systemd/system/container-mysql.service /home/kbtu/container-mysql.service
sudo systemctl daemon-reload
sudo systemctl enable --now container-mysql

TASK 4:

sudo vi /usr/local/bin/mysql-healthcheck.sh

#!/bin/bash
if ! sudo podman exec mysql mysqladmin -u root -pStrongPassword123 ping | grep -q "alive"; then
  logger -t mysql-healthcheck "MySQL not responding - restarting"
  sudo podman restart mysql
else
  logger -t mysql-healthcheck "MySQL healthy"
fi

sudo chmod +x /usr/local/bin/mysql-healthcheck.sh
sudo cp /usr/local/bin/mysql-healthcheck.sh /home/kbtu/mysql-healthcheck.sh

sudo vi /etc/systemd/system/mysql-healthcheck.service

[Unit]
Description=MySQL Health Check
[Service]
Type=oneshot
ExecStart=/usr/local/bin/mysql-healthcheck.sh

sudo cp /etc/systemd/system/mysql-healthcheck.service /home/kbtu/mysql-healthcheck.service

sudo vi /etc/systemd/system/mysql-healthcheck.timer

[Unit]
Description=MySQL Health Check Timer
[Timer]
OnBootSec=3min
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target

sudo cp /etc/systemd/system/mysql-healthcheck.timer /home/kbtu/mysql-healthcheck.timer
sudo systemctl daemon-reload
sudo systemctl enable --now mysql-healthcheck.timer

TASK 5

sudo vi /etc/nftables.conf

#!/usr/sbin/nft -f
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority 0;
    ct state established,related accept
    iif "lo" accept
    tcp dport { 22, 4200 } accept
    drop
  }
  chain forward { type filter hook forward priority 0; }
  chain output { type filter hook output priority 0; }
}

sudo cp /etc/nftables.conf /home/kbtu/nftables.conf
sudo nft -f /etc/nftables.conf
sudo systemctl enable nftables
