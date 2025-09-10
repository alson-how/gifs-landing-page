# Logistics SaaS Landing Page with Email Integration

A Node.js application with EmailJS integration and SQLite database for handling contact forms and email functionality.

## Features

- **Contact Form Processing**: Store contact information in SQLite database
- **Email Integration**: Send emails using EmailJS service
- **Welcome Emails**: Automatic welcome emails to users
- **Database Management**: SQLite database for storing contacts and email logs
- **API Endpoints**: RESTful API for contact management
- **Health Check**: Monitor server and email configuration status

## Project Structure

```
├── server.js              # Main server file
├── database.js            # Database management class
├── emailService.js        # EmailJS service integration
├── package.json           # Node.js dependencies
├── .env                   # Environment variables (configure this)
├── .env.example          # Environment variables template
├── database.db           # SQLite database (created automatically)
└── logistics-saas-proposal.html  # Landing page
```

## Installation

1. Install dependencies:
```bash
npm install
```

2. Configure EmailJS:
   - Copy `.env.example` to `.env`
   - Sign up at [EmailJS](https://www.emailjs.com/)
   - Create a service and template
   - Update the `.env` file with your EmailJS credentials:

```env
EMAILJS_SERVICE_ID=your_service_id
EMAILJS_TEMPLATE_ID=your_template_id
EMAILJS_PUBLIC_KEY=your_public_key
EMAILJS_PRIVATE_KEY=your_private_key
TO_EMAIL=your-email@example.com
PORT=3000
```

## Usage

### Start the server:
```bash
npm start
# or
npm run dev
```

The server will run on `http://localhost:3000`

### API Endpoints

#### POST /api/contact
Submit a new contact form
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "company": "Example Corp",
  "message": "Hello, I'm interested in your services",
  "phone": "+1-555-123-4567"
}
```

#### POST /api/send-email
Send email only (without storing to database)
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "company": "Example Corp",
  "message": "Hello, I'm interested in your services",
  "phone": "+1-555-123-4567"
}
```

#### GET /api/contacts
Get all contacts from database

#### GET /api/contacts/:id
Get specific contact by ID

#### GET /api/health
Check server status and configuration

## Database Schema

### contacts table
- `id` - Primary key
- `name` - Contact name
- `email` - Contact email
- `company` - Company name (optional)
- `message` - Contact message
- `phone` - Phone number (optional)
- `created_at` - Timestamp
- `updated_at` - Timestamp

### email_logs table
- `id` - Primary key
- `contact_id` - Foreign key to contacts
- `email_type` - Type of email sent
- `status` - Email status (sent/failed)
- `error_message` - Error details if failed
- `sent_at` - Timestamp when sent
- `created_at` - Timestamp

## EmailJS Template Variables

Your EmailJS template should include these variables:
- `{{from_name}}` - Sender name
- `{{from_email}}` - Sender email
- `{{company}}` - Company name
- `{{phone}}` - Phone number
- `{{message}}` - Message content
- `{{to_email}}` - Recipient email
- `{{reply_to}}` - Reply-to email

## Docker Deployment

### Quick Start with Docker

1. **Build and run with Docker Compose**:
```bash
# Create .env file with your EmailJS configuration
cp .env.example .env
# Edit .env with your actual EmailJS credentials

# Start the application
docker-compose up -d
```

2. **Access the application**:
   - Application: http://localhost:3000
   - Health check: http://localhost:3000/api/health

### Docker Commands

```bash
# Build the Docker image
docker build -t logistics-email-app .

# Run the container
docker run -d \
  -p 3000:3000 \
  -v logistics_data:/usr/src/app/data \
  --env-file .env \
  --name logistics-app \
  logistics-email-app

# View logs
docker logs logistics-app

# Stop and remove
docker stop logistics-app
docker rm logistics-app
```

### Production Deployment with Nginx

For production with SSL and reverse proxy:

```bash
# Start with nginx reverse proxy
docker-compose --profile production up -d

# Configure SSL certificates in ./ssl/ directory
# Update nginx.conf with your domain name
```

### Docker Features

- **Security**: Non-root user, minimal Alpine image
- **Health Checks**: Built-in container health monitoring
- **Persistence**: SQLite database stored in Docker volume
- **Rate Limiting**: Nginx configuration with API rate limits
- **SSL Ready**: Production-ready HTTPS configuration
- **Auto-restart**: Container restarts automatically on failure

## Development

The application includes:
- Modular architecture with separate database and email services
- Error handling and logging
- Graceful server shutdown
- Health check endpoint for monitoring
- Comprehensive API responses

## Testing

Test the endpoints using curl:

```bash
# Health check
curl http://localhost:3000/api/health

# Submit contact form
curl -X POST http://localhost:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","message":"Test message"}'

# Get all contacts
curl http://localhost:3000/api/contacts
```

## Security Notes

- Environment variables are used for sensitive configuration
- Input validation on required fields
- Error handling prevents information disclosure
- Database uses prepared statements to prevent SQL injection

## License

ISC