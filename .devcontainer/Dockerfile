# Use the official Laravel Sail image as a base
FROM laravelsail/php:8.3

# Install MySQL client
RUN apt-get update && apt-get install -y mysql-client

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*