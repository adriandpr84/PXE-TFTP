# PXE Boot + Instalación Desatendida de Ubuntu Server

## Descripción

Este proyecto demuestra el despliegue automático de nodos mediante **PXE (Preboot Execution Environment)** y **Ubuntu Autoinstall**.

Se utilizan los siguientes servicios:

- **DHCP** → asignación automática de direcciones IP
- **TFTP** → distribución del bootloader y archivos de arranque
- **HTTP** → distribución de la imagen de instalación y perfiles Autoinstall

Cada nodo puede recibir un **perfil de instalación distinto** según su dirección **MAC**.

---

## Entorno de la demo

- **1 VM servidor PXE**: Instalación limpia de Ubuntu Server 22.04
- **2 VMs cliente**

**Topología del servidor PXE:**

| Interfaz | Tipo | Uso |
|----------|------|-----|
| enp0s3   | NAT  | Acceso a internet |
| enp0s8   | Host-Only | Conexión con host |
| enp0s9   | Red interna | Red PXE (DHCP/TFTP/HTTP) |

**IP del servidor PXE (red interna):** `192.168.1.1`

### Clientes

| Interfaz | Tipo |
|----------|------|
| enp0s3 | Red interna (PXE) |
| enp0s8 | NAT |

---


# Demo paso a paso

### Instalación de dependencias

```bash
sudo apt update

sudo apt install -y tftpd-hpa isc-dhcp-server apache2 syslinux pxelinux syslinux-common
```
---

### Netplan
Configurar la interfaz de la red interna (`/etc/netplan/50-cloud-init.yaml`)
```
network:
    ethernets:
        enp0s3:
            dhcp4: true
        enp0s8:
            dhcp4: true
        enp0s9:
          dhcp4: false
          addresses:
            - 192.168.1.1/24
    version: 2
```
Aplicar configuración 
```bash
netplan apply
```

## Configurar el servidor TFTP
Crear estructura de directorios
```bash
mkdir -p /srv/tftp/pxelinux.cfg
mkdir -p /srv/tftp/images
```
Dar permisos al servicio TFTP
```bash
sudo chown -R tftp:tftp /srv/tftp
sudo chmod -R 755 /srv/tftp
```
Copiar archivos de PXE al servidor TFTP
```bash
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /srv/tftp/
```
Configurar servidor TFTP (`/etc/default/tftpd-hpa`)
```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```
Reiniciar servicio:
```
sudo systemctl restart tftpd-hpa
sudo systemctl enable tftpd-hpa
```

## Configuración del servidor DHCP:
Copiar la [configuración del servidor DHCP](./dhcp/dhcpd.conf) incluida en el repositorio
```bash
sudo cp dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
```

Especificar interfaz DHCP(`/etc/default/isc-dhcp-server`)
```
INTERFACESv4="enp0s9"
```

Iniciar el servidor DHCP
```
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
```
## Preparar archivos de instalación de Ubuntu
Crear directorios necesarios:
```bash
sudo mkdir -p /srv/tftp/images/ubuntu-22.04
sudo mkdir -p /var/www/html/ubuntu-22.04
```

Descargar ISO en el directorio del servidor HTTP:
```bash
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
mv ubuntu-22.04.5-live-server-amd64.iso /var/www/html/ubuntu-22.04
```

Montar ISO
```bash
sudo mkdir /mnt/ubuntu-iso
sudo mount -o loop /var/www/html/ubuntu-22.04/ubuntu-22.04*.iso /mnt/ubuntu-iso
```

Copiar kernel e initrd al directorio del servidor TFTP
```bash
sudo cp /mnt/ubuntu-iso/casper/vmlinuz /srv/tftp/images/ubuntu-22.04/
sudo cp /mnt/ubuntu-iso/casper/initrd /srv/tftp/images/ubuntu-22.04/
```

Desmontar ISO
```bash
sudo umount /mnt/ubuntu-iso
```

# Configuración PXE

Copiar la [configuración del menú PXE](.pxe/pxelinux.cfg):

```bash
sudo cp -r pxe/pxelinux.cfg /srv/tftp/
```
- [menu PXE nodo 1](.pxe/pxelinux.cfg/01-12-34-56-78-90-ab)
- [menu PXE nodo 2](.pxe/pxelinux.cfg/01-12-34-56-78-90-ba)

---
## Preparar autoinstall

Copiar los [autoinstall del repositorio](./autoinstall) al directorio del servidor HTTP
```bash
sudo cp -r autoinstall/ /var/www/html/
sudo cp -r autoinstall/ /var/www/html/
```
- [autoinstall nodo 1](./autoinstall/nodo1/user-data)
- [autoinstall nodo 2](./autoinstall/nodo2/user-data)
---


