const sqlite3 = require('sqlite3').verbose();
const path = require('path');

class Database {
    constructor(dbPath = process.env.DB_PATH || './data/database.db') {
        this.db = new sqlite3.Database(dbPath, (err) => {
            if (err) {
                console.error('Error opening database:', err.message);
            } else {
                console.log('Connected to SQLite database');
                this.initializeSchema();
            }
        });
    }

    initializeSchema() {
        const createContactsTable = `
            CREATE TABLE IF NOT EXISTS contacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                company TEXT,
                message TEXT,
                phone TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `;

        const createEmailLogsTable = `
            CREATE TABLE IF NOT EXISTS email_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                contact_id INTEGER,
                email_type TEXT DEFAULT 'contact_form',
                status TEXT DEFAULT 'pending',
                error_message TEXT,
                sent_at DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (contact_id) REFERENCES contacts (id)
            )
        `;

        this.db.serialize(() => {
            this.db.run(createContactsTable, (err) => {
                if (err) {
                    console.error('Error creating contacts table:', err.message);
                } else {
                    console.log('Contacts table ready');
                }
            });

            this.db.run(createEmailLogsTable, (err) => {
                if (err) {
                    console.error('Error creating email_logs table:', err.message);
                } else {
                    console.log('Email logs table ready');
                }
            });
        });
    }

    insertContact(contactData) {
        return new Promise((resolve, reject) => {
            const { name, email, company, message, phone } = contactData;
            const stmt = this.db.prepare(`
                INSERT INTO contacts (name, email, company, message, phone) 
                VALUES (?, ?, ?, ?, ?)
            `);
            
            stmt.run([name, email, company || '', message, phone || ''], function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve(this.lastID);
                }
            });
            stmt.finalize();
        });
    }

    logEmail(contactId, emailType, status, errorMessage = null) {
        return new Promise((resolve, reject) => {
            const stmt = this.db.prepare(`
                INSERT INTO email_logs (contact_id, email_type, status, error_message, sent_at) 
                VALUES (?, ?, ?, ?, ?)
            `);
            
            const sentAt = status === 'sent' ? new Date().toISOString() : null;
            
            stmt.run([contactId, emailType, status, errorMessage, sentAt], function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve(this.lastID);
                }
            });
            stmt.finalize();
        });
    }

    getAllContacts() {
        return new Promise((resolve, reject) => {
            this.db.all(`
                SELECT c.*, el.status as email_status, el.sent_at as email_sent_at
                FROM contacts c
                LEFT JOIN email_logs el ON c.id = el.contact_id
                ORDER BY c.created_at DESC
            `, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows);
                }
            });
        });
    }

    getContactById(id) {
        return new Promise((resolve, reject) => {
            this.db.get(`
                SELECT c.*, el.status as email_status, el.sent_at as email_sent_at
                FROM contacts c
                LEFT JOIN email_logs el ON c.id = el.contact_id
                WHERE c.id = ?
            `, [id], (err, row) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(row);
                }
            });
        });
    }

    close() {
        return new Promise((resolve, reject) => {
            this.db.close((err) => {
                if (err) {
                    reject(err);
                } else {
                    console.log('Database connection closed');
                    resolve();
                }
            });
        });
    }
}

module.exports = Database;