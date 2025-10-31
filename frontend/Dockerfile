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
