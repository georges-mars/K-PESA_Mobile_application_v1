# K-PESA - Mobile Money Bridge Platform

A Flutter-based mobile application that bridges M-Pesa with trading platforms (Deriv, Binance) for seamless money transfers and trading.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Environment Setup](#environment-setup)
- [Database Setup](#database-setup)
- [Backend Configuration](#backend-configuration)
- [Frontend Configuration](#frontend-configuration)
- [Running the Application](#running-the-application)
- [Database Management](#database-management)
- [Encryption Key Management](#encryption-key-management)
- [API Documentation](#api-documentation)
- [Troubleshooting](#troubleshooting)
- [Deployment](#deployment)

## 🚀 Prerequisites

### Required Software
```bash
# Node.js (v18+ recommended)
node --version  # Should be 18+

# Flutter (v3.10+)
flutter --version

# PostgreSQL (v13+)
psql --version

# Git
git --version
```

### Development Tools
- **IDE**: VSCode with Flutter/Dart extensions
- **Database Client**: pgAdmin, DBeaver, or psql CLI
- **API Testing**: Postman or Thunder Client
- **Email**: Gmail account with App Password for SMTP

## 📁 Project Structure

```
K-PESA/
├── backend/                 # Node.js Express API
│   ├── src/
│   │   ├── controllers/     # API route handlers
│   │   ├── services/        # Business logic
│   │   ├── middleware/      # Auth, validation, rate limiting
│   │   ├── config/          # Database, logger configuration
│   │   └── routes/          # API route definitions
│   ├── migrations/          # SQL migration files
│   ├── .env                 # Environment variables
│   ├── package.json         # Node.js dependencies
│   └── server.js           # Application entry point
├── kpesa/                  # Flutter mobile app
│   ├── lib/
│   │   ├── screens/        # UI screens
│   │   ├── services/       # API calls, storage
│   │   ├── models/         # Data models
│   │   └── main.dart       # App entry point
│   ├── android/            # Android-specific code
│   ├── assets/             # Images, fonts, etc.
│   └── pubspec.yaml        # Flutter dependencies
└── README.md               # This file
```

## 🔧 Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/k-pesa.git
cd K-PESA
```

### 2. Backend Setup
```bash
cd backend
npm install
```

### 3. Frontend Setup
```bash
cd ../kpesa
flutter pub get
```

## 🗄️ Database Setup

### 1. Install PostgreSQL
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib

# macOS
brew install postgresql

# Windows
# Download from https://www.postgresql.org/download/windows/
```

### 2. Create Database and User
```bash
# Access PostgreSQL
sudo -u postgres psql

# Create database and user
CREATE DATABASE kpesa;
CREATE USER kpesa_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE kpesa TO kpesa_user;
\q
```

### 3. Run Migrations
```bash
cd backend
node migrate.js
```

## ⚙️ Backend Configuration

### 1. Environment Variables

Create `backend/.env` file:

```env
# Server Configuration
PORT=3000
BASE_URL=http://your-ipv4-address:3000
NODE_ENV=development

# JWT Configuration
JWT_SECRET=your_jwt_secret_min_32_chars_recommended
JWT_EXPIRES_IN=15m
REFRESH_TOKEN_EXPIRES_DAYS=7

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=kpesa
DB_USER=kpesa_user
DB_PASSWORD=your_secure_password

# M-Pesa Daraja API (Safaricom)
MPESA_CONSUMER_KEY=your_mpesa_consumer_key
MPESA_CONSUMER_SECRET=your_mpesa_consumer_secret
MPESA_SHORT_CODE=your_shortcode
MPESA_PASSKEY=your_passkey
MPESA_INITIATOR_NAME=your_initiator_name
MPESA_SECURITY_CREDENTIAL=your_security_credential
MPESA_ENV=sandbox  # or 'production'

# Africa's Talking SMS API
AT_USERNAME=your_at_username
AT_API_KEY=your_africas_talking_api_key

# Email Configuration (Gmail SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_gmail_app_password
EMAIL_FROM=noreply@your-domain.com

# Deriv OAuth
DERIV_APP_ID=130232

# Encryption (Generated automatically - see below)
MASTER_KEY=will_be_generated_by_key_setup

# CORS Configuration
ALLOWED_ORIGINS=*

# Logging
LOG_LEVEL=info
```

### 2. IP Address Configuration

**Important**: Update `BASE_URL` for mobile testing:

```bash
# Find your local IP address
# Windows
ipconfig

# macOS/Linux
ifconfig

# Update BASE_URL in .env
BASE_URL=http://192.168.1.100:3000  # Replace with your IPv4
```

### 3. Generate Encryption Keys
```bash
cd backend
node key-setup.js
```

**This will**:
- Generate a secure `MASTER_KEY`
- Create domain-specific encryption keys
- Email the master key to the configured email address
- Update your `.env` file automatically

### 4. Email Setup for Key Management

**To change the recipient email for encryption keys**:

1. **Update email in key-setup.js**:
```javascript
// Edit line 88 in backend/key-setup.js
to: 'your-new-email@gmail.com',  // Change this email
```

2. **Update email in reset-and-email-keys.js**:
```javascript
// Edit the script to change recipient email
// Search for 'georgesmars8@gmail.com' and replace with your email
```

3. **Or use environment variable**:
```bash
# Add to .env
ADMIN_EMAIL=your-admin@email.com

# Update scripts to use process.env.ADMIN_EMAIL
```

## 📱 Frontend Configuration

### 1. Update API Base URL

Edit `kpesa/lib/services/api_service.dart`:

```dart
class ApiService {
  // Update this URL to match your backend IP
  static const String baseUrl = 'http://192.168.1.100:3000/api/v1';

  // Rest of the code...
}
```

### 2. Update Android Network Security

Edit `kpesa/android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">192.168.1.100</domain>
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

### 3. Configure Deep Links

Ensure `kpesa/android/app/src/main/AndroidManifest.xml` has:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">

    <!-- Deep link for OAuth callbacks -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="kpesa" android:host="deriv-callback" />
    </intent-filter>
</activity>
```

## 🚀 Running the Application

### 1. Start Backend Server
```bash
cd backend

# Development mode with auto-reload
npm run dev

# Or production mode
npm start
```

Backend will run on: `http://your-ip:3000`

### 2. Start Flutter App
```bash
cd kpesa

# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or run on connected device
flutter run
```

### 3. Verify Connection

Test API endpoint:
```bash
curl http://your-ip:3000/api/v1/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

## 🗄️ Database Management

### View Database Contents
```bash
# Connect to database
psql -h localhost -U kpesa_user -d kpesa

# List all tables
\dt

# View users
SELECT id, email, created_at FROM users;

# View transactions
SELECT * FROM transactions ORDER BY created_at DESC LIMIT 10;

# Exit
\q
```

### Clear All Data

**⚠️ Warning: This will DELETE ALL DATA permanently!**

#### Method 1: Using Node.js Script
```bash
cd backend
node clear-database.js
```

#### Method 2: Using SQL
```bash
psql -h localhost -U kpesa_user -d kpesa

-- Clear all data but keep table structure
TRUNCATE TABLE affiliate_redemptions RESTART IDENTITY CASCADE;
TRUNCATE TABLE transactions RESTART IDENTITY CASCADE;
TRUNCATE TABLE refresh_tokens RESTART IDENTITY CASCADE;
TRUNCATE TABLE otps RESTART IDENTITY CASCADE;
TRUNCATE TABLE payment_methods RESTART IDENTITY CASCADE;
TRUNCATE TABLE users RESTART IDENTITY CASCADE;
TRUNCATE TABLE encryption_keys RESTART IDENTITY CASCADE;

\q
```

#### Method 3: Complete Reset with New Keys
```bash
cd backend
node reset-and-email-keys.js
```

**This script will**:
1. Clear all database tables
2. Generate new encryption keys
3. Email new keys to configured addresses
4. Reset ID sequences

## 🔐 Encryption Key Management

### Understanding the Key System

K-PESA uses a **2-layer encryption hierarchy**:

1. **Master Key (KEK)**: Stored in `.env`, encrypts domain keys
2. **Domain Keys (DEK)**: Stored in database, encrypt actual data

**Data Domains**:
- `user_pii`: Full names, display names
- `payment`: Phone numbers, bank account details
- `external`: Deriv tokens, Binance IDs
- `payment_hmac`: HMAC keys for searchable data

### Generate New Keys

#### For New Setup
```bash
cd backend
node key-setup.js
```

#### For Key Rotation (Weekly Recommended)
```bash
cd backend
node key-rotation.js
```

#### Emergency Key Reset
```bash
cd backend
node reset-and-email-keys.js
```

### Configure Email Recipients

**Option 1: Update Scripts Directly**

Edit `backend/key-setup.js` line 88:
```javascript
to: 'new-admin@company.com',  // Change recipient email
```

Edit `backend/email-master-key.js`:
```javascript
to: 'new-admin@company.com',
```

**Option 2: Use Environment Variables**

Add to `backend/.env`:
```env
ADMIN_EMAIL=admin@yourcompany.com
SECURITY_EMAIL=security@yourcompany.com
```

Update scripts to use:
```javascript
to: process.env.ADMIN_EMAIL || 'fallback@email.com',
```

### Email Multiple Recipients

Modify email scripts to send to multiple addresses:
```javascript
// In key-setup.js or email-master-key.js
const recipients = [
  process.env.ADMIN_EMAIL,
  process.env.SECURITY_EMAIL,
  'backup@yourcompany.com'
].filter(Boolean).join(',');

await transporter.sendMail({
  from: `"K-PESA Security" <${process.env.EMAIL_FROM}>`,
  to: recipients,  // Send to multiple emails
  subject: '🔐 K-PESA Master Encryption Key - SECURE BACKUP',
  html: emailBody,
});
```

### Key Security Best Practices

1. **Store keys securely**: Use password managers (1Password, Bitwarden)
2. **Regular rotation**: Run key rotation weekly
3. **Backup keys**: Keep encrypted backups of master keys
4. **Monitor access**: Log who accesses encryption keys
5. **Separate environments**: Different keys for dev/staging/production

### Manual Key Update

If you need to manually update the master key:

1. **Update .env file**:
```bash
# Edit backend/.env
MASTER_KEY=new_64_character_hex_string_here
```

2. **Restart backend server**:
```bash
npm restart
```

3. **Verify encryption works**:
```bash
# Test by creating a user or sending OTP
curl -X POST http://localhost:3000/api/v1/otp/send \
  -H "Content-Type: application/json" \
  -d '{"destination": "test@email.com", "type": "email", "purpose": "signup"}'
```

## 📚 API Documentation

### Base URL
```
http://your-ip:3000/api/v1
```

### Authentication
Most endpoints require a Bearer token:
```bash
Authorization: Bearer your_jwt_token
```

### Key Endpoints

#### Authentication
```bash
# Send OTP
POST /otp/send
{
  "destination": "user@email.com",
  "type": "email",
  "purpose": "signup"
}

# Verify OTP
POST /otp/verify
{
  "destination": "user@email.com",
  "otp": "123456",
  "purpose": "signup"
}

# Register
POST /auth/register
{
  "email": "user@email.com",
  "password": "password123",
  "verificationToken": "token_from_otp",
  "fullName": "John Doe",
  "derivName": "John Doe",
  "derivAccount": "CR12345",
  ...
}

# Login
POST /auth/login
{
  "email": "user@email.com",
  "password": "password123"
}
```

#### User Management
```bash
# Get profile
GET /user/profile
Authorization: Bearer token

# Update profile
PUT /user/profile
{
  "fullName": "New Name",
  "displayName": "Display Name"
}

# Get balances
GET /user/balances
```

#### Payment Methods
```bash
# List payment methods
GET /user/payment-methods

# Add payment method
POST /user/payment-methods
{
  "type": "mpesa",
  "phoneNumber": "+254712345678"
}
```

#### Transactions
```bash
# Get transactions
GET /user/transactions

# Create deposit
POST /transactions/deposit
{
  "amount": 100,
  "currency": "USD",
  "paymentMethodId": "uuid"
}

# Create withdrawal
POST /transactions/withdraw
{
  "amount": 50,
  "currency": "USD",
  "destinationType": "mpesa"
}
```

### Response Format
```json
{
  "success": true,
  "data": { ... },
  "message": "Success message"
}
```

### Error Format
```json
{
  "success": false,
  "error": "Error message",
  "details": { ... }
}
```

## 🔧 Troubleshooting

### Common Issues

#### Backend Won't Start

**Issue**: `EADDRINUSE: Port 3000 already in use`
```bash
# Kill process on port 3000
# Windows
netstat -ano | findstr :3000
taskkill /PID <process_id> /F

# macOS/Linux
lsof -ti:3000 | xargs kill -9

# Or change port in .env
PORT=3001
```

**Issue**: Database connection failed
```bash
# Check PostgreSQL is running
# Windows
sc query postgresql-x64-13

# macOS
brew services list | grep postgresql

# Linux
systemctl status postgresql

# Test connection
psql -h localhost -U kpesa_user -d kpesa
```

**Issue**: Encryption key errors
```bash
# Regenerate keys
cd backend
node key-setup.js

# Check .env has MASTER_KEY (64 hex characters)
grep MASTER_KEY .env
```

#### Flutter App Issues

**Issue**: Network connection failed
1. Verify backend is running: `curl http://your-ip:3000/api/v1/health`
2. Check IP address in `api_service.dart`
3. Ensure Android network security config allows HTTP

**Issue**: OAuth callback not working
1. Check deep link configuration in `AndroidManifest.xml`
2. Verify Deriv app ID in backend `.env`
3. Test deep link: `adb shell am start -W -a android.intent.action.VIEW -d "kpesa://deriv-callback" com.yourpackage`

**Issue**: Build fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check for missing assets
flutter build apk --verbose
```

#### Database Issues

**Issue**: Migration fails
```bash
# Check if tables exist
psql -h localhost -U kpesa_user -d kpesa -c "\dt"

# Drop and recreate database
dropdb -U kpesa_user kpesa
createdb -U kpesa_user kpesa
node migrate.js
```

**Issue**: Encryption/decryption fails
1. Check `MASTER_KEY` is exactly 64 hex characters
2. Ensure encryption_keys table has data
3. Regenerate keys: `node key-setup.js`

### Debug Mode

**Enable verbose logging**:

Backend `.env`:
```env
LOG_LEVEL=debug
```

Flutter:
```bash
flutter run --verbose
flutter logs
```

### Performance Issues

**Database optimization**:
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('kpesa'));

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@email.com';

-- Rebuild indexes
REINDEX DATABASE kpesa;
```

**Backend performance**:
```bash
# Monitor memory usage
node --max-old-space-size=4096 server.js

# Enable performance monitoring
npm install clinic
npx clinic doctor -- node server.js
```

## 🚀 Deployment

### Production Environment Setup

#### 1. Environment Variables
```env
# Production .env
NODE_ENV=production
PORT=443
BASE_URL=https://api.k-pesa.tech

# Use strong secrets
JWT_SECRET=your_production_jwt_secret_min_64_chars
MASTER_KEY=production_master_key_64_hex_chars

# Production database
DB_HOST=your-production-db-host
DB_NAME=kpesa_production
DB_USER=kpesa_production
DB_PASSWORD=very_secure_production_password

# SSL/TLS
SSL_CERT_PATH=/path/to/certificate.crt
SSL_KEY_PATH=/path/to/private.key

# Production APIs
MPESA_ENV=production
# ... other production credentials
```

#### 2. Database Setup
```bash
# Create production database
createdb kpesa_production

# Run migrations
NODE_ENV=production node migrate.js

# Generate production keys
NODE_ENV=production node key-setup.js
```

#### 3. SSL/HTTPS Setup
```bash
# Install SSL certificate
# Option 1: Let's Encrypt
sudo certbot --nginx -d api.k-pesa.tech

# Option 2: Manual certificate
# Place files in /etc/ssl/certs/
# Update .env with paths
```

#### 4. Process Management
```bash
# Install PM2
npm install -g pm2

# Start application
pm2 start server.js --name k-pesa-api

# Auto-restart on reboot
pm2 startup
pm2 save

# Monitor
pm2 monit
```

#### 5. Nginx Reverse Proxy
```nginx
# /etc/nginx/sites-available/k-pesa
server {
    listen 443 ssl;
    server_name api.k-pesa.tech;

    ssl_certificate /etc/ssl/certs/k-pesa.crt;
    ssl_certificate_key /etc/ssl/private/k-pesa.key;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

#### 6. Flutter Production Build
```bash
# Build release APK
flutter build apk --release

# Build App Bundle (for Google Play Store)
flutter build appbundle --release

# Build iOS (on macOS)
flutter build ios --release
```

### Security Checklist

- [ ] Use HTTPS in production
- [ ] Strong database passwords
- [ ] JWT secret > 64 characters
- [ ] Regular key rotation schedule
- [ ] Rate limiting enabled
- [ ] Input validation on all endpoints
- [ ] CORS properly configured
- [ ] Database backups automated
- [ ] Encryption keys backed up securely
- [ ] Monitoring and alerting setup
- [ ] Security headers configured
- [ ] API versioning implemented

### Monitoring

**Health Check Endpoint**:
```bash
curl https://api.k-pesa.tech/api/v1/health
```

**Database Monitoring**:
```sql
-- Monitor active connections
SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';

-- Monitor query performance
SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC;
```

**Application Logs**:
```bash
# PM2 logs
pm2 logs k-pesa-api

# System logs
journalctl -u nginx
journalctl -u postgresql
```

## 📞 Support

### Getting Help
- **Documentation**: This README.md file
- **Issues**: Create GitHub issues for bugs
- **Development**: Check inline code comments
- **Database**: Use pgAdmin or DBeaver for visual management

### Contributing
1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -m 'Add new feature'`
4. Push branch: `git push origin feature/new-feature`
5. Create Pull Request

### License
This project is licensed under the MIT License - see LICENSE file for details.

---

**⚠️ Security Notice**: Always use strong passwords, enable 2FA where possible, and regularly update encryption keys in production environments.

**📱 Mobile Testing**: Always test on real devices for OAuth flows and deep links, as emulators may not handle these correctly.

**🔑 Key Management**: Never commit `.env` files or encryption keys to version control. Always use secure backup methods for production keys.