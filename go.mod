TASK 1 — Roles
Bash
sudo groupadd sysadm
sudo groupadd dbops

sudo vi /etc/sudoers.d/sysadm
# i → paste → Esc → :wq → Enter
Plaintext
%sysadm ALL=(ALL) NOPASSWD: /bin/systemctl
Bash
sudo chmod 440 /etc/sudoers.d/sysadm
sudo cp /etc/sudoers.d/sysadm /home/kbtu/sysadm.bak

sudo vi /etc/sudoers.d/dbops
# i → paste → Esc → :wq → Enter
Plaintext
%dbops ALL=(ALL) NOPASSWD: /usr/bin/podman exec mysql *
Bash
sudo chmod 440 /etc/sudoers.d/dbops
sudo cp /etc/sudoers.d/dbops /home/kbtu/dbops.bak
TASK 2 — Secure storage + backup + audit
Bash
sudo mkdir -p /var/db/mysql-data /var/backups/mysql
sudo chown 999:999 /var/db/mysql-data
sudo chmod 700 /var/db/mysql-data

sudo vi /usr/local/bin/backup-mysql.sh
# i → paste → Esc → :wq → Enter
Bash
#!/bin/bash
BACKUP_DIR=/var/backups/mysql
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
sudo podman exec mysql mysqldump -u root -pStrongPassword123 --all-databases > "$BACKUP_DIR/backup-${TIMESTAMP}.sql"
echo "Backup done"
Bash
sudo chmod 750 /usr/local/bin/backup-mysql.sh
sudo chown root:sysadm /usr/local/bin/backup-mysql.sh
sudo cp /usr/local/bin/backup-mysql.sh /home/kbtu/backup-mysql.sh

sudo vi /etc/cron.d/mysql-backup
# i → paste → Esc → :wq → Enter
Plaintext
0 2 * * * root /usr/local/bin/backup-mysql.sh
Bash
sudo cp /etc/cron.d/mysql-backup /home/kbtu/mysql-backup.bak

sudo vi /etc/audit/rules.d/mysql-backup.rules
# i → paste → Esc → :wq → Enter
Plaintext
-w /usr/local/bin/backup-mysql.sh -p wa -k mysql-backup-tamper
-w /etc/cron.d/mysql-backup -p wa -k mysql-backup-tamper
Bash
sudo cp /etc/audit/rules.d/mysql-backup.rules /home/kbtu/mysql-backup.rules
sudo augenrules --load
sudo systemctl enable --now auditd
TASK 3 — Run MySQL with limits + auto-start
Bash
sudo podman run -d \
--name mysql \
--network host \
--memory 512m \
--memory-swap 512m \
--cpus 1.0 \
-v /var/db/mysql-data:/var/lib/mysql:Z \
-e MYSQL_ROOT_PASSWORD=StrongPassword123 \
-e MYSQL_DATABASE=appdb docker.io/library/mysql:latest

sudo vi /etc/systemd/system/container-mysql.service
# i → paste → Esc → :wq → Enter
Ini, TOML
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

# Verify
sudo podman exec mysql mysqladmin -u root -pStrongPassword123 ping
TASK 4 — Health check: mysqladmin ping → restart if failing
Bash
sudo vi /usr/local/bin/mysql-healthcheck.sh
# i → paste → Esc → :wq → Enter
Bash
#!/bin/bash
if ! sudo podman exec mysql mysqladmin -u root -pStrongPassword123 ping | grep -q "alive"; then
  logger -t mysql-healthcheck "MySQL not responding - restarting"
  sudo podman restart mysql
else
  logger -t mysql-healthcheck "MySQL healthy"
fi
Bash
sudo chmod +x /usr/local/bin/mysql-healthcheck.sh
sudo cp /usr/local/bin/mysql-healthcheck.sh /home/kbtu/mysql-healthcheck.sh

sudo vi /etc/systemd/system/mysql-healthcheck.service
# i → paste → Esc → :wq → Enter
Ini, TOML
[Unit]
Description=MySQL Health Check
[Service]
Type=oneshot
ExecStart=/usr/local/bin/mysql-healthcheck.sh
Bash
sudo cp /etc/systemd/system/mysql-healthcheck.service /home/kbtu/mysql-healthcheck.service

sudo vi /etc/systemd/system/mysql-healthcheck.timer
# i → paste → Esc → :wq → Enter
Ini, TOML
[Unit]
Description=MySQL Health Check Timer
[Timer]
OnBootSec=3min
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target
Bash
sudo cp /etc/systemd/system/mysql-healthcheck.timer /home/kbtu/mysql-healthcheck.timer
sudo systemctl daemon-reload
sudo systemctl enable --now mysql-healthcheck.timer
TASK 5 — nftables: only 22 and 4200
Bash
sudo vi /etc/nftables.conf
# i → paste → Esc → :wq → Enter
Plaintext
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
Bash
sudo cp /etc/nftables.conf /home/kbtu/nftables.conf
sudo nft -f /etc/nftables.conf
sudo systemctl enable nftables
