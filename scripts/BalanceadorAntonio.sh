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