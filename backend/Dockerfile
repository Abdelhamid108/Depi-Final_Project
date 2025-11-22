#Node.js version and linux Base version 
FROM node:18-alpine3.17

#Working Directory where build would take place
WORKDIR /app

#Copy Package files only first.
COPY package*.json ./

#Install dependencies while ignoring peer and engine versions 
RUN npm install --legacy-peer-deps --ignore-engines


#Copy application files.
COPY . . 

#Build the application
RUN npm run build 

EXPOSE 5000

#Start the app
CMD ["npm", "run", "prod"]

