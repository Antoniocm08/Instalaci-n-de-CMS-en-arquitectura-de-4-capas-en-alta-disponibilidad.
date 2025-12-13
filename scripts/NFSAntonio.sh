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