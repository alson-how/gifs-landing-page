const emailjs = require('@emailjs/nodejs');
require('dotenv').config();

class EmailService {
    constructor() {
        this.serviceId = process.env.EMAILJS_SERVICE_ID;
        this.templateId = process.env.EMAILJS_TEMPLATE_ID;
        this.publicKey = process.env.EMAILJS_PUBLIC_KEY;
        this.privateKey = process.env.EMAILJS_PRIVATE_KEY;
        this.toEmail = process.env.TO_EMAIL;

        if (!this.serviceId || !this.templateId || !this.publicKey || !this.privateKey) {
            console.warn('EmailJS configuration incomplete. Please check your environment variables.');
        }
    }

    async sendContactEmail(contactData) {
        try {
            const { name, email, company, message, phone } = contactData;

            const templateParams = {
                from_name: name,
                from_email: email,
                company: company || 'Not specified',
                phone: phone || 'Not provided',
                message: message,
                to_email: this.toEmail,
                reply_to: email
            };

            const response = await emailjs.send(
                this.serviceId,
                this.templateId,
                templateParams,
                {
                    publicKey: this.publicKey,
                    privateKey: this.privateKey,
                }
            );

            return {
                success: true,
                messageId: response.text,
                message: 'Email sent successfully'
            };

        } catch (error) {
            console.error('EmailJS Error:', error);
            return {
                success: false,
                error: error.message || 'Failed to send email',
                details: error
            };
        }
    }

    async sendWelcomeEmail(contactData) {
        try {
            const { name, email } = contactData;

            const templateParams = {
                to_name: name,
                to_email: email,
                from_name: 'Logistics AI Platform',
                message: `Thank you for your interest in our Logistics AI Platform. We have received your inquiry and will get back to you within 24 hours.`
            };

            const response = await emailjs.send(
                this.serviceId,
                process.env.EMAILJS_WELCOME_TEMPLATE_ID || this.templateId,
                templateParams,
                {
                    publicKey: this.publicKey,
                    privateKey: this.privateKey,
                }
            );

            return {
                success: true,
                messageId: response.text,
                message: 'Welcome email sent successfully'
            };

        } catch (error) {
            console.error('Welcome Email Error:', error);
            return {
                success: false,
                error: error.message || 'Failed to send welcome email',
                details: error
            };
        }
    }

    validateConfiguration() {
        const missing = [];
        
        if (!this.serviceId) missing.push('EMAILJS_SERVICE_ID');
        if (!this.templateId) missing.push('EMAILJS_TEMPLATE_ID');
        if (!this.publicKey) missing.push('EMAILJS_PUBLIC_KEY');
        if (!this.privateKey) missing.push('EMAILJS_PRIVATE_KEY');
        if (!this.toEmail) missing.push('TO_EMAIL');

        return {
            isValid: missing.length === 0,
            missing: missing
        };
    }
}

module.exports = EmailService;