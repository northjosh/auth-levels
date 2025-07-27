# Auth Levels - Multi-Factor Authentication System

A comprehensive authentication system demonstrating multiple authentication methods including traditional password-based login, Time-based One-Time Passwords (TOTP), and WebAuthn (Passkeys).

## 🚀 Features

- **JWT Authentication** - Secure JSON Web Token based authentication
- **TOTP (2FA)** - Time-based One-Time Password support with QR code generation
- **WebAuthn/Passkeys** - Modern passwordless authentication using biometrics or security keys
- **User Management** - Registration, login, and profile management
- **Settings Dashboard** - Enable/disable authentication methods and manage security settings
- **Modern UI** - Clean, responsive interface built with Next.js and Tailwind CSS

## 🛠️ Tech Stack

### Backend

- **Spring Boot 3.5.3** - Java framework
- **Java 17** - Programming language
- **PostgreSQL** - Database
- **Spring Security** - Security framework
- **JWT** - Token-based authentication
- **Google Authenticator** - TOTP implementation
- **Yubico WebAuthn** - WebAuthn/FIDO2 support

### Frontend

- **Next.js 15** - React framework
- **React 19** - UI library
- **TypeScript** - Type safety
- **Tailwind CSS** - Utility-first CSS framework
- **TanStack Query** - Data fetching and state management
- **Sonner** - Toast notifications
- **WebAuthn API** - Browser WebAuthn support

## 📁 Project Structure

```
auth-levels/
├── backend/                 # Spring Boot backend
│   ├── src/main/java/northjosh/auth/
│   │   ├── controllers/     # REST API controllers
│   │   ├── services/        # Business logic
│   │   ├── repo/           # Data repositories
│   │   ├── dto/            # Data Transfer Objects
│   │   └── config/         # Configuration classes
│   ├── compose.yaml        # Docker Compose for PostgreSQL
│   └── pom.xml            # Maven dependencies
└── frontend/               # Next.js frontend
    ├── app/               # Next.js app router pages
    ├── components/        # React components
    ├── hooks/             # Custom React hooks
    ├── utils/             # Utility functions
    └── package.json       # npm dependencies
```

## 🚀 Quick Start

### Prerequisites

- **Java 17+**
- **Node.js 18+**
- **Docker** (for PostgreSQL)
- **Maven** (or use included wrapper)

### Backend Setup

1. **Start PostgreSQL database:**

   ```bash
   cd backend
   docker-compose up -d
   ```

2. **Set environment variables:**

   ```bash
   export DATABASE_USER=myuser
   export DATABASE_PASS=secret
   # DATABASE_URL defaults to localhost if not set
   ```

3. **Run the Spring Boot application:**

   ```bash
   ./mvnw spring-boot:run
   ```

   The backend will start on `http://localhost:8001`

### Frontend Setup

1. **Install dependencies:**

   ```bash
   cd frontend
   npm install
   ```

2. **Start the development server:**

   ```bash
   npm run dev
   ```

   The frontend will start on `http://localhost:3000`

## 📚 API Documentation

### Authentication Endpoints

#### POST `/auth/signup`

Register a new user account.

**Request Body:**

```json
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "password": "password123",
  "totpEnabled": false
}
```

#### POST `/auth/login`

Authenticate with email and password.

**Request Body:**

```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

#### GET `/auth/me`

Get current user information (requires JWT token).

**Headers:**

```
Authorization: Bearer <jwt_token>
```

#### POST `/auth/verify-totp`

Verify TOTP code during login.

**Request Body:**

```json
{
  "pendingToken": "<pending_jwt>",
  "code": "123456"
}
```

#### POST `/auth/enable-totp`

Enable TOTP for the current user.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

#### POST `/auth/disable-totp`

Disable TOTP for the current user.

### WebAuthn Endpoints

#### POST `/webauthn/register/options`

Get registration options for WebAuthn credential.

#### POST `/webauthn/register`

Complete WebAuthn credential registration.

#### POST `/webauthn/auth/options`

Get authentication options for WebAuthn login.

#### POST `/webauthn/auth/verify`

Verify WebAuthn authentication response.

#### GET `/webauthn/credentials`

List user's registered WebAuthn credentials.

#### DELETE `/webauthn/credentials/{credentialId}`

Delete a specific WebAuthn credential.

## 🔧 Configuration

### Backend Configuration

The application uses the following environment variables:

- `DATABASE_URL` - PostgreSQL host (default: localhost)
- `DATABASE_USER` - Database username
- `DATABASE_PASS` - Database password

### Database Configuration

By default, the application creates the database schema automatically (`spring.jpa.hibernate.ddl-auto=create`). In production, you should change this to `validate` or `update`.

## 🌟 Usage

1. **Registration:** Create a new account with optional TOTP setup
2. **Login:** Authenticate with email/password
3. **TOTP Setup:** Enable 2FA in the settings panel
4. **WebAuthn Registration:** Add passkeys/security keys in settings
5. **Passwordless Login:** Use the "Login with Passkey" button on the login page

## 🔒 Security Features

- **JWT Tokens** - Secure session management
- **Password Hashing** - BCrypt password encryption
- **TOTP 2FA** - Time-based one-time passwords
- **WebAuthn** - FIDO2/Passkey support with public key cryptography
- **CORS Protection** - Cross-origin request handling
- **Input Validation** - Server-side request validation

## 🐛 Troubleshooting

### Common Issues

1. **Database Connection Errors**

   - Ensure PostgreSQL is running: `docker-compose ps`
   - Check environment variables are set correctly

2. **WebAuthn Issues**

   - Use HTTPS in production (required for WebAuthn)
   - Ensure browser supports WebAuthn
   - Check console for detailed error messages

3. **TOTP Problems**
   - Verify system time is synchronized
   - Check authenticator app is configured correctly

### Development Notes

- The backend runs on port 8001 to avoid conflicts
- Frontend development server includes hot reloading
- Database schema is recreated on each restart (development mode)

## 📄 License

This project is for educational and demonstration purposes.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For questions or issues, please check the troubleshooting section above or create an issue in the repository.
