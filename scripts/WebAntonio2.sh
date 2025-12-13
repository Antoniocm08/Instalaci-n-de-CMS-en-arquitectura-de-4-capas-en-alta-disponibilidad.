#!/bin/bash
# Espera inicial para asegurar conectividad de red
sleep 10

# Configura servidores DNS públicos
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Actualiza la lista de paquetes
apt-get update -qq

#Instalar Nginx y cliente NFS
apt-get install -y nginx nfs-common
# Cliente MariaDB (solo para pruebas)
sudo apt-get install -y mariadb-client

# Crea el punto de montaje para la aplicación web
mkdir -p /var/www/html/webapp

# Monta el directorio NFS exportado por el servidor NFS
mount -t nfs 192.168.70.10:/var/www/html/webapp /var/www/html/webapp
# Hace el montaje persistente tras reinicios
echo "192.168.70.10:/var/www/html/webapp /var/www/html/webapp nfs defaults 0 0" >> /etc/fstab

# Virtual Host de la aplicación web
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    listen 80;
    server_name _;
    # Directorio raíz compartido por NFS
    root /var/www/html/webapp;
    index index.php index.html index.htm;

    # Logs del servidor web
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    # Procesamiento de PHP vía PHP-FPM remoto
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        # PHP-FPM centralizado (serverNFSAntonio)
        fastcgi_pass 192.168.70.10:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    # Seguridad básica
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Habilita el sitio configurado
ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
# Elimina el sitio por defecto de Nginx
rm -f /etc/nginx/sites-enabled/default

# Comprueba la sintaxis de Nginx
nginx -t

# Reinicia y habilita Nginx
systemctl restart nginx
systemctl enable nginx
echo "Web 2 configurado correctamente."