# Development Guide

This guide provides detailed information for developers working on the Auth Levels project.

## Development Environment Setup

### 1. Prerequisites Installation

#### Java Development Kit (JDK) 17+

```bash
# macOS (using Homebrew)
brew install openjdk@17

# Ubuntu/Debian
sudo apt install openjdk-17-jdk

# Verify installation
java -version
javac -version
```

#### Node.js 18+

```bash
# macOS (using Homebrew)
brew install node

# Ubuntu/Debian (using NodeSource)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

#### Docker & Docker Compose

```bash
# macOS (using Homebrew)
brew install docker docker-compose

# Ubuntu/Debian
sudo apt install docker.io docker-compose

# Verify installation
docker --version
docker-compose --version
```

### 2. Project Setup

#### Clone and Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd auth-levels

# Create environment files
cp backend/.env.example backend/.env
```

#### Backend Setup

```bash
cd backend

# Start PostgreSQL database
docker-compose up -d

# Verify database is running
docker-compose ps

# Set environment variables (Linux/macOS)
export DATABASE_USER=myuser
export DATABASE_PASS=secret

# Or create a .env file (if using spring-boot-dotenv)
echo "DATABASE_USER=myuser" >> .env
echo "DATABASE_PASS=secret" >> .env

# Run the application
./mvnw spring-boot:run

# Alternative: Run in development mode with auto-restart
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-Dspring.profiles.active=dev"
```

#### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev

# Alternative: Start with specific port
npm run dev -- --port 3001
```

### 3. Development Workflow

#### Backend Development

```bash
# Run tests
./mvnw test

# Build the application
./mvnw clean package

# Run with specific profile
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Code formatting (using Spotless)
./mvnw spotless:apply

# Check code formatting
./mvnw spotless:check
```

#### Frontend Development

```bash
# Install new dependencies
npm install <package-name>

# Run linting
npm run lint

# Build for production
npm run build

# Start production server
npm run start

# Type checking
npx tsc --noEmit
```

### 4. Database Management

#### Development Database Commands

```bash
# Start database
docker-compose up -d postgres

# Stop database
docker-compose stop postgres

# Reset database (removes all data)
docker-compose down -v
docker-compose up -d postgres

# Access database shell
docker-compose exec postgres psql -U myuser -d mydatabase
```

#### Common SQL Queries for Development

```sql
-- List all tables
\dt

-- View users table
SELECT * FROM users;

-- View WebAuthn credentials
SELECT * FROM web_authn_credential;

-- Reset user TOTP
UPDATE users SET totp_enabled = false, totp_secret = null WHERE email = 'user@example.com';
```

### 5. API Testing

#### Using curl for API Testing

```bash
# Register a new user
curl -X POST http://localhost:8001/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Test","lastName":"User","email":"test@example.com","password":"password123","totpEnabled":false}'

# Login
curl -X POST http://localhost:8001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get user info (replace TOKEN with actual JWT)
curl -X GET http://localhost:8001/auth/me \
  -H "Authorization: Bearer TOKEN"
```

### 6. WebAuthn Development

#### Testing WebAuthn in Development

- **HTTPS Required**: WebAuthn requires HTTPS in production
- **Development Workaround**: Use `localhost` (HTTP allowed for localhost)
- **Browser Support**: Test in Chrome, Firefox, Safari, Edge
- **Debugging**: Use browser dev tools console for WebAuthn errors

#### Common WebAuthn Issues

1. **Invalid Domain**: Ensure relying party ID matches domain
2. **User Verification**: Check if authenticator supports required verification
3. **Credential Conflicts**: Clear existing credentials if testing registration

### 7. Environment Variables Reference

#### Backend (.env)

```bash
# Required
DATABASE_USER=myuser
DATABASE_PASS=secret

# Optional
DATABASE_URL=localhost          # Database host
SPRING_PROFILES_ACTIVE=dev     # Spring profile
SERVER_PORT=8001               # Server port
```

#### Frontend (.env.local)

```bash
# API Base URL (optional, defaults to localhost:8001)
NEXT_PUBLIC_API_URL=http://localhost:8001

# Environment
NODE_ENV=development
```

### 8. Debugging Tips

#### Backend Debugging

- **Logs**: Check console output for SQL queries and errors
- **Database**: Use `spring.jpa.show-sql=true` for SQL logging
- **Profiles**: Use different profiles for dev/test/prod configurations
- **IDE Debug**: Set breakpoints in controllers and services

#### Frontend Debugging

- **React Dev Tools**: Install browser extension for component inspection
- **Network Tab**: Monitor API calls and responses
- **Console Errors**: Check browser console for JavaScript errors
- **React Query Dev Tools**: Already included for API state debugging

### 9. Code Style and Standards

#### Backend (Java)

- Follow Spring Boot conventions
- Use Lombok for reducing boilerplate
- Spotless plugin enforces formatting
- Write tests for services and controllers

#### Frontend (TypeScript/React)

- Use TypeScript strictly
- Follow React hooks patterns
- Use React Query for server state
- ESLint configuration enforces style

### 10. Performance Considerations

#### Development Mode Limitations

- Database schema recreation on restart
- No connection pooling optimization
- Detailed logging enabled
- No caching mechanisms

#### Production Readiness Checklist

- [ ] Change `spring.jpa.hibernate.ddl-auto` to `validate`
- [ ] Set secure JWT secrets
- [ ] Enable HTTPS
- [ ] Configure production database
- [ ] Set up proper logging
- [ ] Configure CORS properly
- [ ] Enable rate limiting
