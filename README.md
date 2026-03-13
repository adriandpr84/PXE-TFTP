
## Instalar los paquetes requeridos
### TFTP server, DHCP server, Apache, syslinux
```
apt install tftpd-hpa isc-dhcp-server apache2 syslinux pxelinux syslinux-common -y
```
## Configurar el servidor TFTP
### Crear Estructura De Directorio
```
mkdir -p /srv/tftp/pxelinux.cfg
mkdir -p /srv/tftp/images
```

### Create TFTP root directory
```
mkdir -p /srv/tftp/pxelinux.cfg
mkdir -p /srv/tftp/images
```

Configurar el servidor TFTP
```
vi /etc/default/tftpd-hpa
```
```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```

Reinicie el servidor TFTP
```
sudo systemctl restart tftpd-hpa
```

Configurar el servidor DHCP
```
vi /etc/dhcp/dhcpd.conf
```
```
# Global options
option domain-name "pxe.local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
default-lease-time 600;
max-lease-time 7200;
authoritative;

# Subnet configuration

subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.100 192.168.1.200;
    option routers 192.168.1.1;
    option subnet-mask 255.255.255.0;

    # PXE boot configuration
    next-server 192.168.1.10;  # TFTP server IP

    # BIOS boot
    filename "pxelinux.0";

    # For UEFI clients, use conditional:
    # if option architecture-type = 00:07 {
    #     filename "efi64/syslinux.efi";
    # } else {
    #     filename "pxelinux.0";
    # }
}
```
Especificar interfaz DHCP
```
vi /etc/default/isc-dhcp-server
```
```
INTERFACESv4="enp0s3"
```
Iniciar el servidor DHCP
```
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
```

Crear menú de arranque PXE
Configuración básica del menú
```
vi /srv/tftp/pxelinux.cfg/default
```
```
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
ONTIMEOUT local
MENU TITLE PXE Boot Menu

LABEL ubuntu-22.04-manual
    MENU LABEL Install Ubuntu 22.04 Server (Manual)
    KERNEL images/ubuntu-22.04/vmlinuz
    INITRD images/ubuntu-22.04/initrd
    APPEND ip=dhcp url=http://192.168.1.10/ubuntu-22.04/ubuntu-22.04-live-server-amd64.iso
```

Preparar archivos de instalación de Ubuntu
Descargar Ubuntu ISO
```
# Create directory for Ubuntu
sudo mkdir -p /srv/tftp/images/ubuntu-22.04
sudo mkdir -p /var/www/html/ubuntu-22.04
```
```
# Download Ubuntu Server ISO
cd /var/www/html/ubuntu-22.04
sudo wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
```

Extraer archivos de arranque
```
# Mount ISO
sudo mkdir /mnt/ubuntu-iso
sudo mount -o loop /var/www/html/ubuntu-22.04/ubuntu-22.04*.iso /mnt/ubuntu-iso
```
```
# Copy kernel and initrd
sudo cp /mnt/ubuntu-iso/casper/vmlinuz /srv/tftp/images/ubuntu-22.04/
sudo cp /mnt/ubuntu-iso/casper/initrd /srv/tftp/images/ubuntu-22.04/
```
```
# Unmount
sudo umount /mnt/ubuntu-iso
```
