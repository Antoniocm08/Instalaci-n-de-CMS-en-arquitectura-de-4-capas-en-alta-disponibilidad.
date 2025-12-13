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