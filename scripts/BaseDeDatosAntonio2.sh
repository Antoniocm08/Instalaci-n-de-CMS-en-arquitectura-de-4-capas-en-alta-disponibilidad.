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