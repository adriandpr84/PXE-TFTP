#!/bin/bash
# Monitor de logs TFTP para enviar eventos a Telegram
# Lee en tiempo real las descargas de TFTP y alerta cuando se baja el arranque PXE, el kernel y el initrd

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/utils.sh"

echo "Iniciando monitorización de logs de TFTP..."

# Leer de journalctl los logs del servicio tftpd-hpa
journalctl -f -u tftpd-hpa -n 0 | grep --line-buffered "RRQ from" | while read -r line; do
    IP=$(echo "$line" | awk -F'RRQ from ' '{print $2}' | awk '{print $1}')
    FILE=$(echo "$line" | awk -F'filename ' '{print $2}')
    
    if [ -z "$IP" ] || [ -z "$FILE" ]; then
        continue
    fi

    # Filtrar archivos clave de arranque (bootloader, kernel e initrd)
    if [ "$FILE" == "pxelinux.0" ] || [[ "$FILE" == *"vmlinuz"* ]] || [[ "$FILE" == *"initrd"* ]]; then
        
        if [ "$FILE" == "pxelinux.0" ]; then
            TYPE="pxe_boot"
        elif [[ "$FILE" == *"vmlinuz"* ]]; then
            TYPE="kernel_download"
        else
            TYPE="initrd_download"
        fi
        
        "$SCRIPT_DIR/notify.sh" tftp_request "$TYPE" "$IP" "$FILE"
    fi
done
