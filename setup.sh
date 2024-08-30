#!/bin/bash

# Variables
PROJECT_NAME="laravel"
DB_USER="sebas"
DB_PASSWORD="sebas"
PHP_VERSION="8.3"
LARAVEL_VERSION="^11.0"

# Ensure necessary dependencies are installed
sudo apt update
sudo apt install -y php$PHP_VERSION php$PHP_VERSION-zip php$PHP_VERSION-xml unzip curl

# Verify the installation of required PHP extensions
php -m | grep -E 'xml|dom'

# Remove existing file named 'laravel-vite' if it exists
if [ -f "/mnt/d/Programming/$PROJECT_NAME" ]; then
    rm "/mnt/d/Programming/$PROJECT_NAME"
fi

# 1. Create a new Laravel project
composer create-project --prefer-dist "laravel/laravel:$LARAVEL_VERSION" "$PROJECT_NAME"
cd "$PROJECT_NAME" || exit

# 2. Configure Laravel Sail and Docker
composer require laravel/sail --dev
php artisan sail:install

# 3. Configure Docker to use PHP 8.3 and add additional services
# Set the docker-compose.yml file with the specified content
cat <<EOL > docker-compose.yml
services:
    laravel.test:
        build:
            context: ./docker/php
            dockerfile: Dockerfile
            args:
                PHP_VERSION: "8.3"
        image: sail-8.3/app
        extra_hosts:
            - 'host.docker.internal:host-gateway'
        ports:
            - '\${APP_PORT:-80}:80'
            - '\${VITE_PORT:-5173}:\${VITE_PORT:-5173}'
        environment:
            WWWUSER: '\${WWWUSER}'
            LARAVEL_SAIL: 1
            XDEBUG_MODE: '\${SAIL_XDEBUG_MODE:-off}'
            XDEBUG_CONFIG: '\${SAIL_XDEBUG_CONFIG:-client_host=host.docker.internal}'
            IGNITION_LOCAL_SITES_PATH: '\${PWD}'
        volumes:
            - '.:/var/www/html'
        networks:
            - sail
        depends_on:
            - mysql
            - meilisearch
            - selenium
            - redis
            - mailhog
    mysql:
        image: 'mysql/mysql-server:8.0'
        ports:
            - '\${FORWARD_DB_PORT:-3306}:3306'
        environment:
            MYSQL_ROOT_PASSWORD: '\${DB_PASSWORD}'
            MYSQL_ROOT_HOST: '%'
            MYSQL_DATABASE: '\${DB_DATABASE}'
            MYSQL_USER: '\${DB_USERNAME}'
            MYSQL_PASSWORD: '\${DB_PASSWORD}'
            MYSQL_ALLOW_EMPTY_PASSWORD: 1
        volumes:
            - 'sail-mysql:/var/lib/mysql'
            - './vendor/laravel/sail/database/mysql/create-testing-database.sh:/docker-entrypoint-initdb.d/10-create-testing-database.sh'
        networks:
            - sail
        healthcheck:
            test:
                - CMD
                - mysqladmin
                - ping
                - '-p\${DB_PASSWORD}'
            retries: 3
            timeout: 5s
    meilisearch:
        image: 'getmeili/meilisearch:latest'
        ports:
            - '7700:7700'
        networks:
            - sail
    selenium:
        image: 'selenium/standalone-chrome'
        volumes:
            - '/dev/shm:/dev/shm'
        networks:
            - sail
    redis:
        image: 'redis:alpine'
        ports:
            - '6379:6379'
        networks:
            - sail
    mailhog:
        image: 'mailhog/mailhog'
        ports:
            - '1025:1025'
            - '8025:8025'
        networks:
            - sail
networks:
    sail:
        driver: bridge
volumes:
    sail-mysql:
        driver: local
EOL

# Create the Dockerfile in docker/php/Dockerfile
mkdir -p docker/php
echo 'FROM laravelsail/php:8.3' > docker/php/Dockerfile

# 4. Install and configure Tailwind CSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Configure Tailwind CSS in the tailwind.config.js file
cat <<EOL > tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./resources/**/*.blade.php",
    "./resources/**/*.js",
    "./resources/**/*.vue",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOL

# Install Vite and the Laravel Vite package
cat <<EOL > vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from 'tailwindcss';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
    ],
    css: {
        postcss: {
          plugins: [tailwindcss()],
        },
    }
});
EOL

# Set Tailwind CSS directives in resources/css/app.css
mkdir -p resources/css
cat <<EOL > resources/css/app.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOL

npm install

# Set content in resources/views/welcome.blade.php
mkdir -p resources/views
cat <<EOL > resources/views/welcome.blade.php
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
    @vite('resources/css/app.css')
</head>
<body>
    <h1 class="text-grey-600">Welcome to Laravel with Vite</h1>
</body>
</html>
EOL

# 5. Configure Laravel to use a MySQL database
# Edit the .env file to configure the database connection
sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
sed -i "s/DB_HOST=.*/DB_HOST=mysql/" .env
sed -i "s/DB_PORT=.*/DB_PORT=3306/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=laravel/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env

# 6. Start the Docker containers
./vendor/bin/sail up -d

# Create the sessions table migration
php artisan make:migration create_sessions_table --table=sessions

# Run the migrations
./vendor/bin/sail artisan migrate

echo "Laravel project completed."