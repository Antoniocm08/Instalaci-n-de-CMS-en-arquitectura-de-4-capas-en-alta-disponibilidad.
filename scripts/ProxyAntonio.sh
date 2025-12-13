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