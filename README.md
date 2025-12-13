# Instalaci-n-de-CMS-en-arquitectura-de-4-capas-en-alta-disponibilidad.
# Despliegue de Aplicación Web “Gestión de Usuarios” en Infraestructura LEMP de Alta Disponibilidad

## Índice
1. [Objetivo](#objetivo)
2. [Estructura de la Infraestructura](#estructura-de-la-infraestructura)
   - [Capa 1: Balanceador de Carga (Pública)](#capa-1-balanceador-de-carga-pública)
   - [Capa 2: BackEnd (Servidores Web + NFS + PHP-FPM)](#capa-2-backend-servidores-web--nfs--php-fpm)
   - [Capa 3: Balanceador de Base de Datos](#capa-3-balanceador-de-base-de-datos)
   - [Capa 4: Base de Datos](#capa-4-base-de-datos)
3. [ Infraestructura visual](#infraestructura-visual)
4. [Provisionamiento](#provisionamiento)
5. [Herramientas Empleadas](#herramientas-empleadas)
6. [Esquema Resumido](#esquema-resumido)

---

## Objetivo
Implementar una aplicación web denominada **Gestión de Usuarios** sobre una infraestructura **LEMP** en **alta disponibilidad** distribuida en **4 capas**, utilizando **Vagrant** (box Debian) y **VirtualBox** para el entorno local.

---

## Estructura de la Infraestructura

### Capa 1: Balanceador de Carga (Pública)
- **Máquina:** `balanceadorAntonio`
- **IP** `192.168.50.10`
- **Servicio:** `Nginx`
- **Función:** 
  - Actúa como punto de entrada público.
  - Distribuye el tráfico de clientes hacia los servidores web de la capa 2.
- **Configuración:**
  - Balanceo de carga mediante **round-robin** o similar.
  - Acceso abierto desde la red pública (puertos HTTP/HTTPS).

---

### Capa 2: BackEnd (Servidores Web + NFS + PHP-FPM)
- **Máquinas:**
  - `serverweb1Antonio` → servidor web Nginx
  - **IP** `192.168.70.11`
  - `serverweb2Antonio` → servidor web Nginx
  - **IP** `192.168.70.12`
  - `serverNFSAntonio` → servidor NFS + motor PHP-FPM
  - **IP** `192.168.70.10`
- **Funciones:**
  - Servidores web gestionan las peticiones distribuidas desde el balanceador.
  - Acceso a archivos compartidos por **NFS** desde `serverNFSTuAntonio`.
  - Procesamiento de código PHP mediante **PHP-FPM** localizado también en `serverNFSTuAntonio`.
- **Notas:**
  - Ninguna máquina de esta capa estará expuesta a red pública.
  - El contenido del CMS se compartirá desde la carpeta NFS.

---

### Capa 3: Balanceador de Base de Datos
- **Máquina:** `proxyAntonio`
- **IP** `192.168.80.10`
- **Servicio:** `HAProxy`
- **Función:**
  - Balancear las conexiones entre las aplicaciones web (capa 2) y el servidor de base de datos (capa 4).
  - Garantizar disponibilidad y distribución de carga en el acceso a datos.

---

### Capa 4: Base de Datos
- **Máquina:** `BaseDeDatos1Antonio/BaseDeDatos2Antonio`
- **IP** `192.168.90.11` y `192.168.90.12`
- **Servicio:** `MariaDB`
- **Función:**
  - Almacenar toda la información de la aplicación **Gestión de Usuarios**.
  - Acceso restringido únicamente al balanceador de bases de datos (HAProxy).
- **Seguridad:**
  - No expuesta a red pública.
  - Configuración de usuarios y permisos específicos para el CMS.

---
## Infraestructura visual

            [ Cliente ]
                |
        [ Balanceador Nginx ]
                |
     [ Web1 ]            [ Web2 ]
        |                   |
        +------- NFS -------+
                |
           [ PHP-FPM ]
                |
          [ HAProxy BD ]
                |
      [ Galera db1 <-> db2 ]


---
## Provisionamiento
- Todo el entorno se desplegará y configurará automáticamente mediante **ficheros de provisionamiento** que dentro de eelos estaran explicados cada linea .
- El aprovisionamiento incluirá:
  - Instalación y configuración de servicios (Nginx, MariaDB, PHP-FPM, NFS, HAProxy).
  - Creación de usuarios, permisos y carpetas compartidas.
  - Montaje automático de las carpetas NFS en los servidores web.
  - Sincronización entre las máquinas virtuales mediante Vagrant.
### Vagrantfile
``` bash
config.vm.define "db1Antonio" do |db1|
  db1.vm.hostname = "db1Antonio"
  db1.vm.network "private_network", ip: "192.168.90.11"
  db1.vm.provision "shell", path: "BaseDeDatosAntonio1.sh"
end

 
config.vm.define "db2Antonio" do |db2|
  db2.vm.hostname = "db2Antonio"
  db2.vm.network "private_network", ip: "192.168.90.12"
  db2.vm.provision "shell", path: "BaseDeDatosAntonio2.sh"
end

 
config.vm.define "proxyBDAntonio" do |proxy|
  proxy.vm.hostname = "proxyBDAntonio"
  proxy.vm.network "private_network", ip: "192.168.80.10"
  proxy.vm.network "private_network", ip: "192.168.90.10"
  proxy.vm.provision "shell", path: "ProxyAntonio.sh"
end


config.vm.define "serverNFSAntonio" do |nfs|
  nfs.vm.hostname = "serverNFSAntonio"
  nfs.vm.network "private_network", ip: "192.168.70.10"
  nfs.vm.network "private_network", ip: "192.168.80.11"
  nfs.vm.provision "shell", path: "NFSAntonio.sh"
end


config.vm.define "serverweb1Antonio" do |web1|
  web1.vm.hostname = "serverweb1Antonio"
  web1.vm.network "private_network", ip: "192.168.70.11"
  web1.vm.provision "shell", path: "WebAntonio1.sh"
end


config.vm.define "serverweb2Antonio" do |web2|
  web2.vm.hostname = "serverweb2Antonio"
  web2.vm.network "private_network", ip: "192.168.70.12"
  web2.vm.provision "shell", path: "WebAntonio2.sh"
end


config.vm.define "balanceadorAntonio" do |bl|
  bl.vm.hostname = "balanceadorAntonio"
  bl.vm.network "private_network", ip: "192.168.50.10"
  bl.vm.network "private_network", ip: "192.168.70.13"
  bl.vm.network "forwarded_port", guest: 80, host: 8080
  bl.vm.provision "shell", path: "BalanceadorAntonio.sh"
end

```

### Balanceador
# Funciones principales:
# - Espera inicial para asegurar conectividad
# - Configuración manual de DNS
# - Actualización del sistema
# - Instalación y configuración de Nginx como balanceador de carga
# - Activación del servicio al arranque

```bash
#!/bin/bash
# Espera 10 segundos antes de empezar.
# Útil en entornos virtualizados o cloud donde la red tarda en levantarse
sleep 10

# Sobrescribe el archivo /etc/resolv.conf con un DNS público 
# tee se usa para escribir con permisos de root

echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
# Añade un segundo DNS  como respaldo
# -a indica que se añade al final del archivo
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Actualiza la lista de paquetes disponibles desde los repositorios
apt-get update

# Instala Nginx sin pedir confirmación (-y)
apt-get install -y nginx

# Se crea un nuevo archivo de configuración del sitio llamado "balancer"
# en sites-available. El uso de EOF permite escribir un bloque completo de texto
cat > /etc/nginx/sites-available/balancer << 'EOF'
upstream backend_servers {
   # Algoritmo de balanceo por defecto: round-robin
   # Otras opciones posibles:
   # least_conn; -> envía la petición al servidor con menos conexiones
   # ip_hash; -> el mismo cliente siempre va al mismo servidor
    
   # Servidores web del cluster LAMP
   # max_fails: número de fallos antes de marcar el servidor como caído
   # fail_timeout: tiempo que se considera el servidor no disponible
    server 192.168.70.11:80 max_fails=3 fail_timeout=30s; # serverweb1Antonio
    server 192.168.70.12:80 max_fails=3 fail_timeout=30s; # serverweb2Antonio
}
# Configuración del servidor Nginx
server {
    # Escucha en el puerto HTTP estándar
    listen 80;
    # Acepta cualquier nombre de host
    server_name _;
    
    # Archivos de log del balanceador
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    # Ruta principal: reenvía el tráfico a los servidores backend
    location / {
        proxy_pass http://backend_servers;
        
        # Cabeceras para preservar información del cliente original
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Tiempos de espera
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Endpoint de comprobación de estado 
    # Útil para monitorización o pruebas rápidas
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Crea un enlace simbólico para habilitar el sitio
ln -sf /etc/nginx/sites-available/balancer /etc/nginx/sites-enabled/
# Elimina el sitio por defecto de Nginx para evitar conflictos
rm -f /etc/nginx/sites-enabled/default

# Comprueba que la configuración de Nginx es correcta
nginx -t

# Reinicia Nginx para aplicar los cambios
systemctl restart nginx
# Habilita Nginx para que arranque automáticamente al iniciar el sistema
systemctl enable nginx
echo "Balanceador de carga configurado correctamente."
```
---



## Herramientas Empleadas
- **Virtualización:** VirtualBox  
- **Gestor de entornos:** Vagrant  
- **Sistema operativo base:** Debian  
- **Servicios principales:**
  - Nginx
  - PHP-FPM
  - NFS
  - HAProxy
  - MariaDB

---
## Prueba con video

https://drive.google.com/file/d/1IZq_q4hDM3VfVfJbisWcBcYLY7oUZ7Wx/view?usp=drive_link
