# Use official Node.js image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy the rest of the app
COPY . .

# Expose port 8080
EXPOSE 8080

# Start the app
CMD ["npm", "start"]

