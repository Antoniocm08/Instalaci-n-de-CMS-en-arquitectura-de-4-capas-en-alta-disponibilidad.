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
