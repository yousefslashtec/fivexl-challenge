# Step 1: Use a lightweight Nginx image designed to run without root privileges
FROM public.ecr.aws/nginx/nginx-unprivileged:alpine-slim

# Step 2: Copy the AWS Lambda Web Adapter binary
# Using the latest stable version (0.9.1) as of 2026
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter

# Step 3: Configure Nginx for Lambda's read-only filesystem
# We redirect all writable paths to /tmp
USER root
RUN sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|g' /etc/nginx/nginx.conf && \
    sed -i 's|/var/cache/nginx|/tmp/nginx_cache|g' /etc/nginx/nginx.conf && \
    mkdir -p /tmp/nginx_cache /var/www/html && \
    chown -R nginx:nginx /tmp/nginx_cache /var/www/html
USER nginx

# Step 4: Create a simple Nginx server configuration
# Listening on port 8080 (the default for Lambda Web Adapter)
RUN echo 'server { \
    listen 8080; \
    server_name localhost; \
    location / { \
        root /var/www/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
    error_page 500 502 503 504 /50x.html; \
}' > /etc/nginx/conf.d/default.conf

# Step 5: Copy your static website files to the web root
# Replace '.' with your specific build directory if necessary (e.g., './dist')
COPY --chown=nginx:nginx . /var/www/html/

# Step 6: Set environment variables for the adapter
ENV PORT=8080
ENV ASYNC_INIT=true
# Optional: Set to 'debug' if you encounter further panics to see detailed logs
ENV AWS_LWA_LOG_LEVEL=info 

# Step 7: Define the entrypoint to start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
