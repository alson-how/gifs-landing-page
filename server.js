const express = require('express');
const cors = require('cors');
const path = require('path');
const Database = require('./database');
const EmailService = require('./emailService');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('.'));

const database = new Database();
const emailService = new EmailService();

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'logistics-saas-proposal.html'));
});

app.post('/api/contact', async (req, res) => {
    const { name, email, company, message, phone } = req.body;

    if (!name || !email || !message) {
        return res.status(400).json({ error: 'Name, email, and message are required' });
    }

    try {
        const contactId = await database.insertContact({
            name, email, company, message, phone
        });

        const emailResult = await emailService.sendContactEmail({
            name, email, company, message, phone
        });

        await database.logEmail(
            contactId, 
            'contact_form', 
            emailResult.success ? 'sent' : 'failed',
            emailResult.success ? null : emailResult.error
        );

        if (emailResult.success) {
            await emailService.sendWelcomeEmail({ name, email });
        }

        res.json({ 
            success: true, 
            message: 'Contact information saved and email sent successfully',
            id: contactId,
            emailStatus: emailResult.success ? 'sent' : 'failed'
        });

    } catch (error) {
        console.error('Error processing contact:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/api/send-email', async (req, res) => {
    const { name, email, company, message, phone } = req.body;

    if (!name || !email || !message) {
        return res.status(400).json({ error: 'Name, email, and message are required' });
    }

    try {
        const emailResult = await emailService.sendContactEmail({
            name, email, company, message, phone
        });

        if (emailResult.success) {
            res.json({ 
                success: true, 
                message: emailResult.message
            });
        } else {
            res.status(500).json({ 
                error: emailResult.error,
                details: emailResult.details 
            });
        }

    } catch (error) {
        console.error('Email error:', error);
        res.status(500).json({ 
            error: 'Failed to send email',
            details: error.message 
        });
    }
});

app.get('/api/contacts', async (req, res) => {
    try {
        const contacts = await database.getAllContacts();
        res.json(contacts);
    } catch (error) {
        console.error('Database error:', error.message);
        res.status(500).json({ error: 'Failed to fetch contacts' });
    }
});

app.get('/api/contacts/:id', async (req, res) => {
    try {
        const contact = await database.getContactById(req.params.id);
        if (!contact) {
            return res.status(404).json({ error: 'Contact not found' });
        }
        res.json(contact);
    } catch (error) {
        console.error('Database error:', error.message);
        res.status(500).json({ error: 'Failed to fetch contact' });
    }
});

app.get('/api/health', (req, res) => {
    const emailConfig = emailService.validateConfiguration();
    res.json({
        status: 'OK',
        database: 'Connected',
        email: emailConfig.isValid ? 'Configured' : 'Not configured',
        missingConfig: emailConfig.missing
    });
});

process.on('SIGINT', async () => {
    try {
        await database.close();
        console.log('Server shutdown gracefully');
        process.exit(0);
    } catch (error) {
        console.error('Error during shutdown:', error.message);
        process.exit(1);
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});