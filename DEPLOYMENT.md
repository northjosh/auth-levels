# Deployment Guide

This guide covers deploying the Auth Levels application to production environments.

## 🏗️ Production Architecture

### Recommended Infrastructure

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Frontend      │    │   Backend       │
│   (HTTPS/SSL)   │────│   (Next.js)     │────│   (Spring Boot) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                               ┌─────────────────┐
                                               │   PostgreSQL    │
                                               │   Database      │
                                               └─────────────────┘
```

### Infrastructure Requirements

- **Web Server**: Nginx or Apache (for frontend)
- **Application Server**: Java 17+ JVM
- **Database**: PostgreSQL 12+
- **SSL/TLS**: Required for WebAuthn
- **Memory**: Minimum 512MB for backend, 256MB for frontend
- **Storage**: SSD recommended for database

## 🐳 Docker Deployment

### Docker Compose Production Setup

Create `docker-compose.prod.yml`:

```yaml
version: "3.8"

services:
  database:
    image: postgres:15
    environment:
      POSTGRES_DB: auth_production
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db-init:/docker-entrypoint-initdb.d
    networks:
      - app-network
    restart: unless-stopped

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    environment:
      DATABASE_URL: database
      DATABASE_USER: ${DB_USER}
      DATABASE_PASS: ${DB_PASSWORD}
      SPRING_PROFILES_ACTIVE: prod
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      - database
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.prod
    environment:
      NEXT_PUBLIC_API_URL: https://api.yourdomain.com
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - app-network
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - frontend
      - backend
    networks:
      - app-network
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### Backend Dockerfile

Create `backend/Dockerfile.prod`:

```dockerfile
FROM openjdk:17-jdk-slim

WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build application
RUN ./mvnw clean package -DskipTests

# Run application
EXPOSE 8001
CMD ["java", "-jar", "target/auth-0.0.1-SNAPSHOT.jar"]
```

### Frontend Dockerfile

Create `frontend/Dockerfile.prod`:

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]
```

## 🌐 Nginx Configuration

Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:8001;
    }

    upstream frontend {
        server frontend:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name yourdomain.com www.yourdomain.com;
        return 301 https://$server_name$request_uri;
    }

    # Main HTTPS server
    server {
        listen 443 ssl http2;
        server_name yourdomain.com www.yourdomain.com;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self';" always;

        # Frontend (Next.js)
        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Backend API
        location /auth {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /webauthn {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## ☁️ Cloud Deployment Options

### AWS Deployment

#### Using AWS ECS with Fargate

1. **Create ECR Repositories**:

   ```bash
   aws ecr create-repository --repository-name auth-levels-backend
   aws ecr create-repository --repository-name auth-levels-frontend
   ```

2. **Build and Push Images**:

   ```bash
   # Get login token
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

   # Build and push backend
   docker build -t auth-levels-backend ./backend
   docker tag auth-levels-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-levels-backend:latest
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-levels-backend:latest

   # Build and push frontend
   docker build -t auth-levels-frontend ./frontend
   docker tag auth-levels-frontend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-levels-frontend:latest
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-levels-frontend:latest
   ```

3. **Create ECS Task Definition**:
   ```json
   {
     "family": "auth-levels",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "512",
     "memory": "1024",
     "executionRoleArn": "arn:aws:iam::<account>:role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "backend",
         "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/auth-levels-backend:latest",
         "portMappings": [
           {
             "containerPort": 8001,
             "protocol": "tcp"
           }
         ],
         "environment": [
           {
             "name": "SPRING_PROFILES_ACTIVE",
             "value": "prod"
           }
         ],
         "secrets": [
           {
             "name": "DATABASE_USER",
             "valueFrom": "arn:aws:secretsmanager:us-east-1:<account>:secret:auth-levels-db-user"
           }
         ]
       }
     ]
   }
   ```

### Google Cloud Platform

#### Using Cloud Run

1. **Enable APIs**:

   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   ```

2. **Deploy Backend**:

   ```bash
   cd backend
   gcloud builds submit --tag gcr.io/PROJECT-ID/auth-levels-backend
   gcloud run deploy auth-levels-backend \
     --image gcr.io/PROJECT-ID/auth-levels-backend \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

3. **Deploy Frontend**:
   ```bash
   cd frontend
   gcloud builds submit --tag gcr.io/PROJECT-ID/auth-levels-frontend
   gcloud run deploy auth-levels-frontend \
     --image gcr.io/PROJECT-ID/auth-levels-frontend \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

### Heroku Deployment

#### Backend (Spring Boot)

Create `Procfile` in backend directory:

```
web: java -Dserver.port=$PORT -jar target/auth-0.0.1-SNAPSHOT.jar
```

Deploy:

```bash
cd backend
heroku create auth-levels-backend
heroku addons:create heroku-postgresql:mini
heroku config:set SPRING_PROFILES_ACTIVE=prod
git push heroku main
```

#### Frontend (Next.js)

Create `package.json` script:

```json
{
  "scripts": {
    "heroku-postbuild": "npm run build"
  }
}
```

Deploy:

```bash
cd frontend
heroku create auth-levels-frontend
heroku config:set NEXT_PUBLIC_API_URL=https://auth-levels-backend.herokuapp.com
git push heroku main
```

## 🔒 Production Security Configuration

### Environment Variables

Create `.env.prod`:

```bash
# Database
DATABASE_URL=production-db-host
DATABASE_USER=prod_user
DATABASE_PASS=strong_random_password

# JWT
JWT_SECRET=very-long-cryptographically-secure-secret-key

# Spring Profiles
SPRING_PROFILES_ACTIVE=prod

# WebAuthn
WEBAUTHN_RP_ID=yourdomain.com
WEBAUTHN_RP_NAME=Your App Name
```

### Spring Boot Production Configuration

Create `application-prod.properties`:

```properties
# Database
spring.datasource.url=jdbc:postgresql://${DATABASE_URL}:5432/${DATABASE_NAME}
spring.datasource.username=${DATABASE_USER}
spring.datasource.password=${DATABASE_PASS}
spring.jpa.hibernate.ddl-auto=validate

# Security
server.ssl.enabled=true
server.ssl.key-store-type=PKCS12
server.ssl.key-store=classpath:keystore.p12
server.ssl.key-store-password=${SSL_KEYSTORE_PASSWORD}

# Logging
logging.level.org.springframework.security=WARN
logging.level.com.yubico.webauthn=INFO
logging.pattern.console=%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n

# CORS
app.cors.allowed-origins=${ALLOWED_ORIGINS:https://yourdomain.com}

# Actuator
management.endpoints.web.exposure.include=health,info
management.endpoint.health.show-details=never
```

## 📊 Monitoring and Observability

### Application Monitoring

#### Spring Boot Actuator Endpoints

Add to `pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

Configure monitoring endpoints:

```properties
management.endpoints.web.base-path=/actuator
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoint.health.show-details=when-authorized
```

#### Database Monitoring

Monitor PostgreSQL:

```sql
-- Connection monitoring
SELECT * FROM pg_stat_activity;

-- Database size monitoring
SELECT pg_size_pretty(pg_database_size('auth_production'));

-- Table statistics
SELECT * FROM pg_stat_user_tables;
```

### Log Management

#### Application Logs

Configure structured logging:

```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.3</version>
</dependency>
```

#### Security Event Logging

Log security events:

```java
@Component
public class SecurityEventLogger {

    private static final Logger logger = LoggerFactory.getLogger(SecurityEventLogger.class);

    public void logLoginAttempt(String email, boolean success) {
        if (success) {
            logger.info("Successful login for user: {}", email);
        } else {
            logger.warn("Failed login attempt for user: {}", email);
        }
    }

    public void logWebAuthnEvent(String email, String event, boolean success) {
        logger.info("WebAuthn {} for user: {} - Success: {}", event, email, success);
    }
}
```

## 📋 Production Deployment Checklist

### Pre-Deployment

- [ ] Set all environment variables
- [ ] Configure SSL certificates
- [ ] Set up database with production credentials
- [ ] Configure CORS for production domains
- [ ] Update WebAuthn relying party configuration
- [ ] Set secure JWT secrets
- [ ] Configure proper logging levels
- [ ] Set up monitoring and alerting
- [ ] Test backup and recovery procedures

### Deployment

- [ ] Deploy database changes
- [ ] Deploy backend application
- [ ] Deploy frontend application
- [ ] Configure load balancer/reverse proxy
- [ ] Verify SSL certificate installation
- [ ] Test all authentication flows
- [ ] Verify WebAuthn functionality
- [ ] Test API endpoints
- [ ] Monitor application logs

### Post-Deployment

- [ ] Monitor application performance
- [ ] Check error logs
- [ ] Verify security headers
- [ ] Test user registration/login flows
- [ ] Monitor database performance
- [ ] Set up regular backups
- [ ] Configure log rotation
- [ ] Document production procedures

## 🚨 Incident Response

### Common Production Issues

1. **Database Connection Issues**

   - Check connection pool settings
   - Verify database server status
   - Monitor connection limits

2. **SSL/TLS Problems**

   - Verify certificate validity
   - Check certificate chain
   - Validate domain configuration

3. **WebAuthn Issues**

   - Verify HTTPS configuration
   - Check relying party ID
   - Validate origin settings

4. **High Memory Usage**
   - Monitor JVM heap usage
   - Analyze garbage collection
   - Check for memory leaks

### Emergency Procedures

1. **Application Rollback**

   ```bash
   # Docker deployment
   docker-compose down
   docker-compose up -d --scale backend=0
   docker tag auth-levels-backend:previous auth-levels-backend:latest
   docker-compose up -d
   ```

2. **Database Rollback**

   ```bash
   # Restore from backup
   pg_restore -h localhost -U postgres -d auth_production backup.sql
   ```

3. **Traffic Redirection**
   ```bash
   # Update DNS or load balancer to maintenance page
   ```
