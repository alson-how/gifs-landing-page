# Use the official Node.js runtime as the base image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json (if available)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Create app user to run the application (security best practice)
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Create directory for SQLite database with proper permissions
RUN mkdir -p /usr/src/app/data && chown -R nodejs:nodejs /usr/src/app/data

# Copy the rest of the application code
COPY . .

# Change ownership of the app directory to the nodejs user
RUN chown -R nodejs:nodejs /usr/src/app

# Switch to the nodejs user
USER nodejs

# Create a volume for the SQLite database
VOLUME ["/usr/src/app/data"]

# Expose the port the app runs on
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (res) => { \
    if (res.statusCode !== 200) process.exit(1); \
    res.on('data', () => {}); \
    res.on('end', () => process.exit(0)); \
  }).on('error', () => process.exit(1))"

# Define the command to run the application
CMD ["npm", "start"]