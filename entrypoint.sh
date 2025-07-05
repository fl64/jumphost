#!/bin/sh
set -e

KEY_DIR=/home/$USER/ssh_host_keys
RUN_DIR=/home/$USER/run

mkdir -p $RUN_DIR
chmod 755 $RUN_DIR

if [ ! -f "$KEY_DIR/ssh_host_rsa_key" ]; then
  rm -rf $KEY_DIR/*
  mkdir -p $KEY_DIR

  ssh-keygen -t rsa -b 4096 -f $KEY_DIR/ssh_host_rsa_key -N ""
  ssh-keygen -t ecdsa -f $KEY_DIR/ssh_host_ecdsa_key -N ""
  ssh-keygen -t ed25519 -f $KEY_DIR/ssh_host_ed25519_key -N ""
else
  echo "[init] Use existing keys."
fi

cat <<EOF > /home/$USER/sshd_config
Port 2222
PasswordAuthentication no
PermitRootLogin no
Protocol 2
AllowAgentForwarding yes
AllowTcpForwarding yes
PermitTunnel yes
HostKey $KEY_DIR/ssh_host_rsa_key
HostKey $KEY_DIR/ssh_host_ecdsa_key
HostKey $KEY_DIR/ssh_host_ed25519_key
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
GatewayPorts no
LogLevel DEBUG1
MaxAuthTries 200
MaxStartups 50:30:200
MaxSessions 200
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3
PidFile $RUN_DIR/sshd.pid
# restrict local access
ForceCommand none
X11Forwarding no
PermitTTY no
PermitUserRC no
EOF

echo "[init] SSHD configuration:"

cat /home/$USER/sshd_config

> /home/$USER/.ssh/authorized_keys

while IFS= read -r key_var; do
  eval key="\$$key_var"
  clean_key=$(echo "$key" | tr -d '\r\n')
  if echo "$clean_key" | ssh-keygen -l -f /dev/stdin; then
    echo "Adding key for user $USER: $clean_key"
    echo "$clean_key" >> /home/$USER/.ssh/authorized_keys
  fi
done < <(env | grep '^SSH_' | cut -d= -f1)

chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys
chown -R $USER:$USER /home/$USER/.ssh
chown -R $USER:$USER $RUN_DIR

if [ -z "${WSTUNNEL_DST}" ]; then
  WSTUNNEL_DST="127.0.0.1:2222"
fi

echo "[init] Starting wstunnel, dst host is ${WSTUNNEL_DST}..."
(wstunnel server ws://0.0.0.0:8080 --restrict-to ${WSTUNNEL_DST} 2>&1 | sed 's/^/[wstunnel] /') &

echo "[init] Starting sshd..."

exec /usr/sbin/sshd -D -e -f /home/$USER/sshd_config
