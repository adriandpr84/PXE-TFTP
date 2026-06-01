#!/bin/bash
# Script para notificar eventos de DHCP y TFTP a un chat de Telegram.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/utils.sh"

EVENT=$1
TYPE=""
IP=""
MAC=""
HOSTNAME=""
FILE=""

# 1. Parseo de argumentos según el evento
if [ "$EVENT" == "dhcp_commit" ]; then
    TYPE="ip_assignment"
    IP=$2
    MAC=$3
    HOSTNAME=$4
elif [ "$EVENT" == "tftp_request" ]; then
    TYPE=$2
    IP=$3
    FILE=$4
    MAC=$(get_mac_by_ip "$IP")
else
    echo "Evento no soportado: $EVENT"
    exit 1
fi

# 2. Obtener perfil y hostname
PERFIL="Perfil desconocido"
if [ -n "$MAC" ]; then
    PERFIL=$(get_profile_by_mac "$MAC")
fi

if [ -z "$HOSTNAME" ] && [ -n "$IP" ]; then
    HOSTNAME=$(get_hostname_by_ip "$IP")
    [ -z "$HOSTNAME" ] && HOSTNAME="Desconocido"
fi

# 3. Construcción JSON
JSON=$(cat <<EOF
{
  "event": "$EVENT",
  "type": "$TYPE",
  "ip_address": "$IP",
  "mac_address": "$MAC",
  "hostname": "$HOSTNAME",
  "requested_file": "$FILE",
  "profile": "$PERFIL"
}
EOF
)

# 4. Envío
MENSAJE="<pre><code>$JSON</code></pre>"
send_telegram_message "$MENSAJE"
