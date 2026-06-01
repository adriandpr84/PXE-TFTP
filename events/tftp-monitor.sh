#!/bin/bash
# Monitor de logs TFTP para enviar eventos a Telegram

source "$(dirname "$0")/utils.sh"

echo "Iniciando monitorización de logs de TFTP..."

declare -A LAST_NOTIFIED

# Leer de journalctl los logs del servicio tftpd-hpa
journalctl -f -u tftpd-hpa -n 0 | grep --line-buffered "RRQ from" | while read -r line; do
    IP=$(echo "$line" | awk -F'RRQ from ' '{print $2}' | awk '{print $1}')
    FILE=$(echo "$line" | awk -F'file ' '{print $2}')
    
    if [ -z "$IP" ] || [ -z "$FILE" ]; then
        continue
    fi

    # Filtrar para avisar solo de archivos clave de arranque
    if [ "$FILE" == "pxelinux.0" ] || [[ "$FILE" == *"vmlinuz"* ]]; then
        
        # Evitar ráfagas
        CURRENT_TIME=$(date +%s)
        KEY="${IP}_${FILE}"
        LAST_TIME=${LAST_NOTIFIED[$KEY]:-0}
        
        if [ $((CURRENT_TIME - LAST_TIME)) -lt 10 ]; then
            continue
        fi
        LAST_NOTIFIED[$KEY]=$CURRENT_TIME

        if [ "$FILE" == "pxelinux.0" ]; then
            TYPE="pxe_boot"
        else
            TYPE="kernel_download"
        fi
        
        "$(dirname "$0")/notify.sh" tftp_request "$TYPE" "$IP" "$FILE"
    fi
done
