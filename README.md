# Instalacion-de-CMS-en-arquitectura-de-4-capas-en-alta-disponibilidad.
## Índice
1. [Objetivo](#objetivo)
2. [Estructura de la Infraestructura](#estructura-de-la-infraestructura)
   - [Capa 1: Balanceador de Carga (Pública)](#capa-1-balanceador-de-carga-pública)
   - [Capa 2: BackEnd (Servidores Web + NFS + PHP-FPM)](#capa-2-backend-servidores-web--nfs--php-fpm)
   - [Capa 3: Balanceador de Base de Datos](#capa-3-balanceador-de-base-de-datos)
   - [Capa 4: Base de Datos](#capa-4-base-de-datos)
3. [ Infraestructura visual](#infraestructura-visual)
4. [Provisionamiento](#provisionamiento)
   - [Vagrantfile](#vagrantfile)
   - [Balanceador](#balanceador)
   - [Base de datos 1](#base-de-datos-1)
   - [Base de datos 2](#base-de-datos-2)
   - [NFS](#nfs)
   - [Proxy](#proxy)
   - [Servidores webs](#servidores-webs)
6. [Herramientas Empleadas](#herramientas-empleadas)
7. [Prueba con video](#prueba-con-video)
8. [Conclusion](#conclusion)

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
- Funciones principales:
 - Espera inicial para asegurar conectividad
 - Configuración manual de DNS
 - Actualización del sistema
 - Instalación y configuración de Nginx como balanceador de carga
 - Activación del servicio al arranque

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
### Base de datos 1
- Funciones principales:
 - Configuración básica de red y DNS
 - Instalación de MariaDB + Galera
 - Inicialización del clúster Galera (nodo primario)
 - Creación de base de datos y usuarios
  
```bash
#!/bin/bash
sleep 10

# Configura servidores DNS públicos
# Se sobrescribe resolv.conf 
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Actualiza índices de paquetes sin mostrar demasiada salida (-qq)
apt-get update -qq

# Evita prompts interactivos durante la instalación y instala MariaDB Server y Galera
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync

# MariaDB debe estar detenido antes de aplicar la configuración de Galera
systemctl stop mariadb

# Se crea el archivo de configuración específico de Galera
# en el directorio recomendado por MariaDB
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << 'EOF'
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
# Permite conexiones remotas
bind-address=0.0.0.0

# Habilita Galera
wsrep_on=ON
# Librería del proveedor Galera
wsrep_provider=/usr/lib/galera/libgalera_smm.so

# Nombre lógico del clúster
wsrep_cluster_name="galera_cluster"
# gcomm:// indica comunicación Galera
wsrep_cluster_address="gcomm://192.168.90.11,192.168.90.12"

wsrep_sst_method=rsync

# IP del nodo actual
wsrep_node_address="192.168.90.11"
# Nombre identificativo del nodo
wsrep_node_name="db1Antonio"
EOF

# Arranca el clúster Galera por primera vez
galera_new_cluster

# Espera para asegurar que MariaDB está completamente operativo
sleep 10

# Muestra el estado del servicio
systemctl status mariadb --no-pager

# Se ejecutan comandos SQL directamente contra MariaDB
mysql << 'EOSQL'
-- Crear base de datos
CREATE DATABASE IF NOT EXISTS lamp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuario para la aplicacion
CREATE USER IF NOT EXISTS 'antonio'@'%' IDENTIFIED BY '1234567';
GRANT ALL PRIVILEGES ON lamp_db.* TO 'antonio'@'%';

-- Usuario para  HAProxy 
CREATE USER IF NOT EXISTS 'haproxy'@'%' IDENTIFIED BY '';
GRANT USAGE ON *.* TO 'haproxy'@'%';

-- Crear usuario root remoto para administracion
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

-- Verificar usuarios creados
SELECT User, Host FROM mysql.user WHERE User IN ('antonio', 'haproxy', 'root');
EOSQL

# Habilita MariaDB para iniciar automáticamente al arrancar el sistema
systemctl enable mariadb
# Muestra el tamaño del clúster Galera
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null

echo "Base de datos 1 configurado correctamente."

```
### Base de datos 2
- Funciones principales:
 - Instalación de MariaDB + Galera
 - Configuración como nodo secundario del clúster
 - Unión y sincronización con el nodo primario
```bash
#!/bin/bash
# set -e hace que el script termine inmediatamente si ocurre cualquier error
set -e
# Espera inicial para asegurar conectividad de red
sleep 10

# Configura DNS públicos y suprime la salida estándar
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null

# Actualiza la lista de paquetes de forma silenciosa
apt-get update -qq

# Instalación no interactiva de los componentes necesarios: MariaDB Server y Galera
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client galera-4 rsync

# MariaDB debe estar detenido antes de modificar la configuración
systemctl stop mariadb

# Se escribe la configuración específica de Galera para db2
# La mayor parte coincide con db1, excepto la identidad del nodo
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << 'EOF'
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
# Permite conexiones entrantes desde otros nodos y el proxy
bind-address=0.0.0.0

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so

# Nombre del clúster
wsrep_cluster_name="galera_cluster"
# Direcciones de todos los nodos Galera
wsrep_cluster_address="gcomm://192.168.90.11,192.168.90.12"

wsrep_sst_method=rsync

# IP del nodo secundario
wsrep_node_address="192.168.90.12"
# Nombre del nodo secundario
wsrep_node_name="db2Antonio"
EOF

# El nodo se conecta al clúster existente e inicia la sincronización
systemctl start mariadb


sleep 10

# Estado del servicio MariaDB
systemctl status mariadb --no-pager

#Habilitar MariaDB en el inicio
systemctl enable mariadb
# Muestra variables clave del estado Galera:
# - wsrep_cluster_size -> número de nodos del clúster 
# - wsrep_cluster_status -> estado del clúster 
# - wsrep_ready -> listo para aceptar escrituras
# - wsrep_connected -> conectado al clúster
mysql -e "SHOW STATUS LIKE 'wsrep_%';" | grep -E "(wsrep_cluster_size|wsrep_cluster_status|wsrep_ready|wsrep_connected)"
echo "Base de datos 2 configurado correctamente."
```
### NFS
- Funciones principales:
 - Configuración de DNS
 - Instalación de NFS Server
 - Instalación y configuración de PHP-FPM
 - Exportación NFS del código de la aplicación web
 - Despliegue automático de una aplicación LAMP de ejemplo
```bash
#!/bin/bash

# Espera inicial para asegurar conectividad de red
sleep 10
# Configuración de servidores DNS públicos
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
# Actualiza índices de paquetes de forma silenciosa
apt-get update -qq
# Instala git para clonar el repositorio de la aplicación
apt-get install -y git

# Instala el servidor NFS
apt-get install -y nfs-kernel-server

# Instala PHP-FPM junto con extensiones habituales para aplicaciones LAMP
apt-get install -y php-fpm php-mysql php-curl php-gd php-mbstring \
    php-xml php-xmlrpc php-soap php-intl php-zip netcat-openbsd

# Se crea el directorio que contendrá el código PHP
mkdir -p /var/www/html/webapp
# Se asigna como propietario al usuario del servidor web (www-data)
chown -R www-data:www-data /var/www/html/webapp
# Permisos estándar de lectura/ejecución
chmod -R 755 /var/www/html/webapp

# Configuración de los recursos NFS exportados
# Solo los servidores web pueden montar este directorio
cat > /etc/exports << 'EOF'
/var/www/html/webapp 192.168.70.11(rw,sync,no_subtree_check,no_root_squash)
/var/www/html/webapp 192.168.70.12(rw,sync,no_subtree_check,no_root_squash)
EOF
# Aplica la configuración de exports
exportfs -a
# Reinicia y habilita el servicio NFS
systemctl restart nfs-kernel-server
systemctl enable nfs-kernel-server

# Obtiene dinámicamente la versión instalada de PHP
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
# Archivo de configuración del pool principal
PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
# Cambia PHP-FPM de socket Unix a puerto TCP 9000
sed -i 's|listen = /run/php/php.*-fpm.sock|listen = 9000|' "$PHP_FPM_CONF"
# Restringe qué clientes pueden conectarse al PHP-FPM
sed -i 's|;listen.allowed_clients.*|listen.allowed_clients = 192.168.70.11,192.168.70.12|' "$PHP_FPM_CONF"
# Reinicia y habilita PHP-FPM
systemctl restart php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm
# Verifica que PHP-FPM escucha en el puerto 9000
sleep 10
netstat -tlnp | grep 9000

# Espera a que el proxy de base de datos  esté disponible
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if nc -z 192.168.80.10 3306 2>/dev/null; then
        echo "La Base de datos esta totalmente disponible"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 10
done

# Limpia posibles restos de ejecuciones anteriores
rm -rf /var/www/html/webapp/*
rm -rf /tmp/lamp
# Clona el repositorio de la práctica LAMP
git clone https://github.com/josejuansanchez/iaw-practica-lamp.git /tmp/lamp

# Copia el código fuente PHP al directorio compartido
cp -r /tmp/lamp/src/* /var/www/html/webapp/

# Archivo de configuración de conexión a base de datos
cat > /var/www/html/webapp/config.php << 'EOF'
<?php
define('DB_HOST', '192.168.80.10');
define('DB_NAME', 'lamp_db');
define('DB_USER', 'lamp_user');
define('DB_PASS', 'lamp_password');


$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

if ($mysqli->connect_error) {
    die("Error de conexion: " . $mysqli->connect_error);
}

$mysqli->set_charset("utf8mb4");
?>
EOF

# Script de instalación de base de datos
cat > /var/www/html/webapp/install.php << 'EOF'
<?php
define('DB_HOST', '192.168.80.10');
define('DB_NAME', 'lamp_db');
define('DB_USER', 'lamp_user');
define('DB_PASS', 'lamp_password');
?>
EOF

# Archivo de diagnóstico PHP
cat > /var/www/html/webapp/info.php << 'EOF'
<?php
phpinfo();
?>
EOF

# Ajusta permisos finales
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp

# Elimina archivos temporales
rm -rf /tmp/lamp
# Lista el contenido final del directorio web
ls -lh /var/www/html/webapp/
echo "Configuracion de NFS y PHP-FPM completada."

```

### Proxy
- Funciones principales:
 - Instalación de HAProxy
 - Configuración como balanceador TCP para MySQL/MariaDB
 - Monitorización básica mediante estadísticas web
```bash
#!/bin/bash
# set -e: el script se detiene si ocurre cualquier error
set -e
# Espera inicial para asegurar conectividad de red
sleep 10

# Configuración de servidores DNS públicos
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf >/dev/null
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null

# Actualiza los índices de paquetes
apt-get update -qq

# Instala HAProxy desde los repositorios oficiales
apt-get install -y haproxy

# Se sobrescribe el archivo principal de configuración de HAProxy
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    # Logs del sistema
    log /dev/log local0
    log /dev/log local1 notice
    # Aislamiento del proceso
    chroot /var/lib/haproxy
    # Socket de administración
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 20s
    # Usuario y grupo de ejecución
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    # Log de conexiones TCP
    option tcplog
    option dontlognull
    timeout connect 10s
    timeout client 1h
    timeout server 1h

# Punto de entrada para clientes de base de datos
# Escucha en el puerto estándar 3306 en todas las interfaces
frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend

# Definición de los nodos del clúster Galera
backend mariadb_backend
    mode tcp
    balance roundrobin
    option tcp-check
    
    tcp-check connect
    
    server db1Antonio 192.168.90.11:3306 check inter 5s rise 2 fall 3
    server db2Antonio 192.168.90.12:3306 check inter 5s rise 2 fall 3

# Interfaz web de monitorización
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    # Permite acciones administrativas
    stats admin if TRUE
    stats auth admin:admin
EOF

# Habilita HAProxy para iniciar automáticamente
systemctl enable haproxy

# Reinicia HAProxy para aplicar la configuración
systemctl restart haproxy

# Espera breve para asegurar que el servicio esté operativo
sleep 10

# Muestra el estado del servicio
systemctl status haproxy --no-pager
echo "HAProxy configurado correctamente para MariaDB."
```

### Servidores webs
- Funciones principales:
- Configuración de DNS y actualización del sistema
- Instalación de Nginx y cliente NFS
- Montaje del directorio web desde el servidor NFS
- Configuración de Nginx para usar PHP-FPM remoto
```bash
#!/bin/bash
# Espera inicial para asegurar conectividad de red
sleep 10

# Configura servidores DNS públicos
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Actualiza los índices de paquetes
apt-get update -qq
# Instala Nginx (servidor web) y soporte para NFS
apt-get install -y nginx nfs-common
# Cliente MariaDB (útil para pruebas de conexión)
sudo apt-get install -y mariadb-client

# Crea el punto de montaje local
mkdir -p /var/www/html/webapp

# Monta el directorio compartido desde el servidor NFS
# serverNFSAntonio: 192.168.70.10
mount -t nfs 192.168.70.10:/var/www/html/webapp /var/www/html/webapp

# Hace el montaje persistente tras reinicio del sistema
echo "192.168.70.10:/var/www/html/webapp /var/www/html/webapp nfs defaults 0 0" >> /etc/fstab

# Se define un nuevo Virtual Host para la aplicación web
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    # Escucha en el puerto HTTP estándar
    listen 80;
    # Acepta cualquier nombre de host
    server_name _;
    # Directorio raíz (montado por NFS)
    root /var/www/html/webapp;
    index index.php index.html index.htm;

    # Logs específicos del servidor web
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    # Procesamiento de archivos PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        # PHP-FPM remoto (serverNFSAntonio)
        fastcgi_pass 192.168.70.10:9000;
        # Ruta completa del script PHP
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    # Seguridad: bloquea acceso a archivos ocultos
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Habilita el sitio web
ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
# Elimina el sitio por defecto para evitar conflictos
rm -f /etc/nginx/sites-enabled/default

# Verifica la configuración de Nginx
nginx -t

# Reinicia Nginx para aplicar los cambios
systemctl restart nginx
# Habilita Nginx al arranque del sistema
systemctl enable nginx
echo "Web 1 configurado correctamente."
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
- Aqui pongo el enclace del screencrash desde mi drive para que lo puedas ver.
https://drive.google.com/file/d/1IZq_q4hDM3VfVfJbisWcBcYLY7oUZ7Wx/view?usp=drive_link

## Conclusion
Se ha desplegado con éxito una aplicación web de **Gestión de Usuarios** sobre una infraestructura en **alta disponibilidad de cuatro capas** basada en LEMP.

El **balanceador Nginx** gestiona el tráfico público y reparte la carga entre dos servidores web que utilizan **NFS** y **PHP-FPM** centralizado. La base de datos se encuentra en un clúster **MariaDB** accesible a través de **HAProxy**, garantizando alta disponibilidad y tolerancia a fallos. 

Todas las capas internas están aisladas de la red pública, aumentando la seguridad. El uso de **Vagrant y VirtualBox** con scripts de aprovisionamiento ha permitido automatizar el despliegue y asegurar reproducibilidad.

En conjunto, la infraestructura es **robusta, escalable y modular**, cumpliendo con los objetivos de disponibilidad y eficiencia.
