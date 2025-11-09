# Docker Documentation

## 1. Overview

This project uses docker to containerize all of application services to be able to use them on different environments.The services containerizedare:
- **Backend**: Node.js API
- **Frontend**: React application
- **Database**: MongoDB

## 2. Folder Structure
```bash
Docker-AE/
├── Docker-compose.yaml
│
├── backend/
│   ├── Dockerfile
│   │
│
├── frontend/
│   ├── Dockerfile
    ├── nginx.conf
    │ 
```
## 3. Backend Dockerfile 

**location:** `backend/Dockerfile`\
**Purpose:** Builds and runs the nodejs API

```Dockerfile
#Node.js version and linux Base version 
FROM node:18-alpine3.17

#Working Directory where build would take place
WORKDIR /app

#Copy Package files only first.
COPY package*.json ./

#Install dependencies while ignoring peer and engine versions 
RUN npm install --legacy-peer-deps --igonre-engines


#Copy application files.
COPY . . 

#Build the application
RUN npm run build 

EXPOSE 5000

#Start the app
CMD ["npm", "run", "prod"]
```
## 4. Frontend Dockerfile

**location:** `frontend/Dockerfile`\
**Purpose:** Builds React frontend and serves it with nginx using multi-stage build.
```Dockerfile
#Multi-Stage build 

#Using nodejs image for react 
FROM node:18-alpine3.17 AS builder

#Set working directory
WORKDIR /app

#Copy package files only.
COPY package*.json ./

#Install production dependencies only
RUN npm install --only=production

#Copy app source code.
COPY . .

#Build the react application
RUN npm run build


From nginx:alpine

#Copy build from previous build stage 
COPY --from=builder /app/build /usr/share/nginx/html

#Copy nginx configuration from current directory as default for nginx in container
COPY nginx.conf /etc/nginx/nginx.conf

Expose 80

#Start nginx
CMD ["nginx", "-g", "daemon off;"]
```

This is a multi-stage. It builds the frontend into static files which are then send to nginx to serve those files.

## 5.Nginx Configuration

**location:** `frontend/nginx.conf`

```nginx.conf

user nginx;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile on;
    keepalive_timeout 65;


    server {
        listen 80;
        server_name myapp.com;

        root /usr/share/nginx/html;
        index index.html;
	
	#API proxy to backend 
        location /api/ {
            proxy_pass http://backend:5000;   
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
	#Serve frontend
        location / {
            try_files $uri $uri/ /index.html;

            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header Referrer-Policy "no-referrer-when-downgrade" always;
            add_header Content-Security-Policy "default-src 'self';" always;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

## 6. Docker Compose
**location:** `/docker-compose.yaml`

```docker-compose.yaml
services:
  backend:
    build: ./backend
    container_name: backend
    restart: always
    depends_on:
      mongodb:
        condition: service_healthy
   
    ports:
      - "5000:5000"
    environment:
      - MONGODB_URI=mongodb://admin:password@mongodb:27017/amazona?authSource=admin
      - AWS_ACCESS_KEY_ID=dummy
      - AWS_SECRET_ACCESS_KEY=dummy
      - AWS_REGION=${AWS_REGION:-eu-north-1}
      - AWS_BUCKET_NAME=${AWS_BUCKET_NAME:-amazona20}
      - JWT_SECRET=${JWT_SECRET:-somethingsecret}
      - PAYPAL_CLIENT_ID=${PAYPAL_CLIENT_ID:-sb}

  frontend:
    build: ./frontend
    container_name: frontend
    restart: always
    ports: 
      - "3000:80"
    environment:
      - REACT_APP_API_URL=

  mongodb:
    image: mongo:6
    container_name: mongodb
    restart: always
    ports:
      - "27017:27017"

    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=password
    
    volumes:
      - mongodb_data:/data/db

    healthcheck:
      test: ["CMD", "mongosh", "--eval","db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mongodb_data:
```
### Explanation:
- Dockercompose file contains the mongoDB service 
- The backend service depends on the mongodb service but only if the service passes the healthcheck.
- Volumes persist mongodb data.

## 7. .env-examples
**location:** `/.env-examples`
**Purpose:** This file is a configuration file used to store environment variables for the application.\
	     It is mainly for storing sensitive data like (API Keys, passwords, and database URLs) so it\ would not be directly in code.
```.env-examples
#The first two varibales is for allowing backend to upload files to the S3 bucket 
AWS_ACCESS_KEY_ID=dummy
AWS_SECRET_ACCESS_KEY=dummy
#THE next two are just information about the S3 bucket, it's region and it's name
AWS_REGION=eu-north-1
AWS_BUCKET_NAME=dummy-bucket
#This variable is important to keep user logged in by verifing the token created to each user as the token verifies user identity
JWT_SECRET=somethingsecret
```
***All the variables are dummy variables for testing.***

## 8. Running the Application

```
#Start all services
docker compose up --build -t
```

```
#Stop all services
docker compose down 
```

```
#view logs
docker compose logs -f backend
docker compose logs -f frontend
```
Access the app
- [frontend](http://<VM-IP>:3000)
