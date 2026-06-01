#!/bin/bash
# Utilidades compartidas para eventos PXE-TFTP

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "ERROR: No se encuentra el archivo .env con las credenciales de Telegram en $SCRIPT_DIR."
    exit 1
fi

# Obtiene el perfil a partir de la MAC leyendo el fichero de PXELINUX
get_profile_by_mac() {
    local MAC=$1
    local MAC_FILE="01-$(echo "$MAC" | tr ':' '-' | tr '[:upper:]' '[:lower:]')"
    local PXE_CONF="/srv/tftp/pxelinux.cfg/$MAC_FILE"
    
    if [ -f "$PXE_CONF" ]; then
        grep "MENU LABEL" "$PXE_CONF" | sed 's/MENU LABEL //'
    else
        echo "Perfil desconocido"
    fi
}

# Obtiene la MAC a partir de la IP leyendo el dhcpd.conf
get_mac_by_ip() {
    local IP=$1
    grep -B1 "fixed-address $IP;" /etc/dhcp/dhcpd.conf | grep "hardware ethernet" | awk '{print $3}' | tr -d ';'
}

# Obtiene el hostname a partir de la IP leyendo el dhcpd.conf
get_hostname_by_ip() {
    local IP=$1
    grep -B2 "fixed-address $IP;" /etc/dhcp/dhcpd.conf | grep "host " | awk '{print $2}'
}

# Envía un mensaje a Telegram
send_telegram_message() {
    local MENSAJE=$1
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=HTML" \
        --data-urlencode "text=${MENSAJE}" > /dev/null
}
