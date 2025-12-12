# Instalaci-n-de-CMS-en-arquitectura-de-4-capas-en-alta-disponibilidad.
# Despliegue de Aplicación Web “Gestión de Usuarios” en Infraestructura LEMP de Alta Disponibilidad

## Índice
1. [Objetivo](#objetivo)
2. [Estructura de la Infraestructura](#estructura-de-la-infraestructura)
   - [Capa 1: Balanceador de Carga (Pública)](#capa-1-balanceador-de-carga-pública)
   - [Capa 2: BackEnd (Servidores Web + NFS + PHP-FPM)](#capa-2-backend-servidores-web--nfs--php-fpm)
   - [Capa 3: Balanceador de Base de Datos](#capa-3-balanceador-de-base-de-datos)
   - [Capa 4: Base de Datos](#capa-4-base-de-datos)
3. [Provisionamiento](#provisionamiento)
4. [Herramientas Empleadas](#herramientas-empleadas)
5. [Esquema Resumido](#esquema-resumido)

---

## Objetivo
Implementar una aplicación web denominada **Gestión de Usuarios** sobre una infraestructura **LEMP** en **alta disponibilidad** distribuida en **4 capas**, utilizando **Vagrant** (box Debian) y **VirtualBox** para el entorno local.

---

## Estructura de la Infraestructura

### Capa 1: Balanceador de Carga (Pública)
- **Máquina:** `balanceadorAntonio`
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
  - `serverweb2Antonio` → servidor web Nginx
  - `serverNFSAntonio` → servidor NFS + motor PHP-FPM
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
- **Servicio:** `HAProxy`
- **Función:**
  - Balancear las conexiones entre las aplicaciones web (capa 2) y el servidor de base de datos (capa 4).
  - Garantizar disponibilidad y distribución de carga en el acceso a datos.

---

### Capa 4: Base de Datos
- **Máquina:** `BaseDeDatos1Antonio/BaseDeDatos2Antonio`
- **Servicio:** `MariaDB`
- **Función:**
  - Almacenar toda la información de la aplicación **Gestión de Usuarios**.
  - Acceso restringido únicamente al balanceador de bases de datos (HAProxy).
- **Seguridad:**
  - No expuesta a red pública.
  - Configuración de usuarios y permisos específicos para el CMS.

---

## Provisionamiento
- Todo el entorno se desplegará y configurará automáticamente mediante **ficheros de provisionamiento** (por ejemplo, *shell scripts* o *Ansible playbooks*).
- El aprovisionamiento incluirá:
  - Instalación y configuración de servicios (Nginx, MariaDB, PHP-FPM, NFS, HAProxy).
  - Creación de usuarios, permisos y carpetas compartidas.
  - Montaje automático de las carpetas NFS en los servidores web.
  - Sincronización entre las máquinas virtuales mediante Vagrant.

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
