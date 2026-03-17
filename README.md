# PXE Boot + Instalación Desatendida

## Descripción

Demo de despliegue automático de nodos mediante PXE (Preboot Execution Environment) e instalación desatendida de Ubuntu Server 22.04.

Se usan DHCP, TFTP y HTTP para asignar IPs, distribuir archivos de arranque y perfiles de instalación.

---

## Entorno de la demo

- **1 VM servidor PXE**: Ubuntu Server 22.04 (instalación limpia)
- **2 VMs cliente**

### Topología de la red
```
             +------------------+
             |  Servidor PXE    |
             |  192.168.1.1     |
             |  enp0s9          |
             +--------+---------+
                      |
       Red interna PXE: 192.168.1.0/24
                      |
       +--------------+--------------+
       |                             |
+------+------------+            +---+----------------+
| Cliente PXE 1     |            | Cliente PXE 2      |
| 192.168.1.50      |            | 192.168.1.51       |
| 12:34:56:78:90:ab |            | 12:34:56:78:90:ba  |
| enp0s3            |            | enp0s3             |
+-------------------+            +--------------------+
```

---
## Estructura del repositorio
```
PXE-TFTP/
├── autoinstall
│   ├── nodo_1
│   │   ├── meta-data
│   │   └── user-data       # Perfil Autoinstall nodo 1
│   └── nodo_2
│       ├── meta-data
│       └── user-data       # Perfil Autoinstall nodo 2
├── dhcp
│   └── dhcpd.conf           # Configuración del servidor DHCP
└── pxe
    └── pxelinux.cfg
        ├── 01-12-34-56-78-90-ab   # Menú PXE nodo 1
        └── 01-12-34-56-78-90-ba   # Menú PXE nodo 2
```
----
## Guía paso a paso
> La guía se realiza como `root`, por lo que los comandos no incluyen `sudo`.
> 
### 1. Instalación de dependencias

```bash
apt update

apt install -y tftpd-hpa isc-dhcp-server apache2 syslinux pxelinux syslinux-common
```


### 2. Configuración de red (Netplan)
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


### 3. Configuración TFTP
> Servirá los archivos de arranque (PXELINUX, kernel e initrd) a los clientes que hagan PXE Boot.

Crear estructura de directorios y permisos
```bash
mkdir -p /srv/tftp/pxelinux.cfg /srv/tftp/images
chown -R tftp:tftp /srv/tftp
chmod -R 755 /srv/tftp
```
Copiar archivos de PXE
```bash
cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
cp /usr/lib/syslinux/modules/bios/*.c32 /srv/tftp/
```
Configurar servidor TFTP (`/etc/default/tftpd-hpa`)
```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```
Reiniciar y habilitar servicio:
```
systemctl restart tftpd-hpa
systemctl enable tftpd-hpa
```

### 4. Configuracion DHCP
> Cada cliente recibe IP automáticamente según su MAC.

Copiar la [configuración del servidor DHCP](./dhcp/dhcpd.conf) incluida:
```bash
cp dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
```

Especificar interfaz DHCP(`/etc/default/isc-dhcp-server`)
```
INTERFACESv4="enp0s9"
```

Reiniciar y habilitar servicio:
```
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server
```
> Cada nodo recibirá IP del servidor DHCP a través de enp0s9.

### 5. Preparar archivos de instalación
Crear directorios necesarios:
```bash
mkdir -p /srv/tftp/images/ubuntu-22.04
mkdir -p /var/www/html/ubuntu-22.04
```

Descargar ISO en el directorio del servidor HTTP:
```bash
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
mv ubuntu-22.04.5-live-server-amd64.iso /var/www/html/ubuntu-22.04
```

Montar ISO
```bash
mkdir /mnt/ubuntu-iso
mount -o loop /var/www/html/ubuntu-22.04/ubuntu-22.04*.iso /mnt/ubuntu-iso
```

Copiar kernel e initrd al directorio del servidor TFTP
```bash
cp /mnt/ubuntu-iso/casper/{vmlinuz,initrd} /srv/tftp/images/ubuntu-22.04/
```

Desmontar ISO
```bash
umount /mnt/ubuntu-iso
```

### 6. Configuración PXE
Copiar [configuración del menú PXE](./pxe/pxelinux.cfg)

```bash
cp -r pxe/pxelinux.cfg /srv/tftp/
```
- [Nodo 1](./pxe/pxelinux.cfg/01-12-34-56-78-90-ab)
- [Nodo 2](./pxe/pxelinux.cfg/01-12-34-56-78-90-ba)
> Cada nodo usa su menú PXE específico según su MAC, que apunta a su perfil de autoinstall.


### 7. Perfiles autoinstall

Copiar [perfiles](./autoinstall) al servidor HTTP
```bash
cp -r autoinstall/ /var/www/html/
```
- [Perfil nodo 1](./autoinstall/nodo_1/user-data)
- [Perfil nodo 2](./autoinstall/nodo_2/user-data)
> Cada cliente descargará automaticamente su perfil según su MAC.

### 8. Arrancar clientes
- Configurar arranque por red (PXE) en cada VM cliente.
- El cliente recibirá IP, cargará PXELINUX, seleccionará su perfil y realizará la instalación automáticamente.


