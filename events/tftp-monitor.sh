#!/bin/bash
# Monitor de logs TFTP para enviar eventos a Telegram
# Lee en tiempo real las descargas de TFTP y alerta cuando se baja el arranque PXE, el menú y el Kernel

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/utils.sh"

echo "Iniciando monitorización de logs de TFTP..."

# Seguimiento del último archivo notificado por IP para evitar enviar mensajes duplicados en el mismo segundo
declare -A LAST_NOTIFIED

# Leer de journalctl los logs del servicio tftpd-hpa
journalctl -f -u tftpd-hpa -n 0 | grep --line-buffered "RRQ from" | while read -r line; do
    IP=$(echo "$line" | awk -F'RRQ from ' '{print $2}' | awk '{print $1}')
    # Soporta tanto "file <nombre>" como "filename <nombre>"
    FILE=$(echo "$line" | sed -E 's/.*file(name)? //')
    
    if [ -z "$IP" ] || [ -z "$FILE" ]; then
        continue
    fi

    # Filtrar para avisar solo de archivos clave de arranque (cargador, menú específico y kernel)
    if [ "$FILE" == "pxelinux.0" ] || [[ "$FILE" == pxelinux.cfg/01-* ]] || [[ "$FILE" == *"vmlinuz"* ]]; then
        
        # Evitar ráfagas (deduplicación básica de 1 segundo por fichero/IP)
        CURRENT_TIME=$(date +%s)
        KEY="${IP}_${FILE}"
        LAST_TIME=${LAST_NOTIFIED[$KEY]:-0}
        
        if [ $((CURRENT_TIME - LAST_TIME)) -lt 1 ]; then
            continue
        fi
        LAST_NOTIFIED[$KEY]=$CURRENT_TIME

        if [ "$FILE" == "pxelinux.0" ]; then
            TYPE="pxe_boot"
        elif [[ "$FILE" == pxelinux.cfg/01-* ]]; then
            TYPE="pxe_menu_load"
        else
            TYPE="kernel_download"
        fi
        
        "$SCRIPT_DIR/notify.sh" tftp_request "$TYPE" "$IP" "$FILE"
    fi
done
