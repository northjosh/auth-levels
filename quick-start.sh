#!/bin/bash

# Auth Levels - Quick Start Script
# This script helps you get the Auth Levels application running quickly

set -e

echo "🚀 Auth Levels - Quick Start Setup"
echo "=================================="

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    if ! command -v java &> /dev/null; then
        echo "❌ Java not found. Please install Java 17+."
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js not found. Please install Node.js 18+."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    echo "✅ All requirements satisfied!"
}

# Setup environment variables
setup_environment() {
    echo "🔧 Setting up environment..."
    
    # Create backend environment file if it doesn't exist
    if [ ! -f "backend/.env" ]; then
        if [ -f "backend/.env.example" ]; then
            cp backend/.env.example backend/.env
            echo "✅ Created backend/.env from example"
        else
            echo "DATABASE_USER=myuser" > backend/.env
            echo "DATABASE_PASS=secret" >> backend/.env
            echo "✅ Created backend/.env with default values"
        fi
    fi
    
    # Export environment variables for current session
    export DATABASE_USER=myuser
    export DATABASE_PASS=secret
    
    echo "✅ Environment configured!"
}

# Start database
start_database() {
    echo "🐘 Starting PostgreSQL database..."
    
    cd backend
    
    # Stop any existing containers
    docker-compose down &> /dev/null || true
    
    # Start database
    docker-compose up -d
    
    # Wait for database to be ready
    echo "⏳ Waiting for database to be ready..."
    sleep 10
    
    # Check if database is running
    if docker-compose ps | grep -q "Up"; then
        echo "✅ Database is running!"
    else
        echo "❌ Failed to start database"
        exit 1
    fi
    
    cd ..
}

# Setup backend
setup_backend() {
    echo "☕ Setting up backend..."
    
    cd backend
    
    # Make Maven wrapper executable
    chmod +x mvnw
    
    # Download dependencies
    echo "📦 Downloading dependencies..."
    ./mvnw dependency:go-offline -q
    
    echo "✅ Backend setup complete!"
    cd ..
}

# Setup frontend
setup_frontend() {
    echo "⚛️  Setting up frontend..."
    
    cd frontend
    
    # Install dependencies
    echo "📦 Installing npm dependencies..."
    npm install --silent
    
    echo "✅ Frontend setup complete!"
    cd ..
}

# Start applications
start_applications() {
    echo "🎯 Starting applications..."
    
    # Start backend in background
    echo "☕ Starting backend (port 8001)..."
    cd backend
    nohup ./mvnw spring-boot:run > ../backend.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > ../backend.pid
    cd ..
    
    # Wait for backend to start
    echo "⏳ Waiting for backend to start..."
    sleep 30
    
    # Check if backend is running
    if curl -s http://localhost:8001/actuator/health > /dev/null 2>&1; then
        echo "✅ Backend is running!"
    else
        echo "⚠️  Backend might still be starting. Check backend.log for details."
    fi
    
    # Start frontend in background
    echo "⚛️  Starting frontend (port 3000)..."
    cd frontend
    nohup npm run dev > ../frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > ../frontend.pid
    cd ..
    
    echo "⏳ Waiting for frontend to start..."
    sleep 15
    
    # Check if frontend is running
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Frontend is running!"
    else
        echo "⚠️  Frontend might still be starting. Check frontend.log for details."
    fi
}

# Display status and next steps
show_status() {
    echo ""
    echo "🎉 Setup Complete!"
    echo "=================="
    echo ""
    echo "🌐 Frontend: http://localhost:3000"
    echo "🔧 Backend:  http://localhost:8001"
    echo "🐘 Database: localhost:5432"
    echo ""
    echo "📋 What's Running:"
    echo "- PostgreSQL database (Docker)"
    echo "- Spring Boot backend (PID: $(cat backend.pid 2>/dev/null || echo 'unknown'))"
    echo "- Next.js frontend (PID: $(cat frontend.pid 2>/dev/null || echo 'unknown'))"
    echo ""
    echo "📖 Next Steps:"
    echo "1. Open http://localhost:3000 in your browser"
    echo "2. Create a new account or login"
    echo "3. Try enabling TOTP in settings"
    echo "4. Register a passkey for WebAuthn"
    echo ""
    echo "🔍 Monitoring:"
    echo "- Backend logs: tail -f backend.log"
    echo "- Frontend logs: tail -f frontend.log"
    echo "- Database logs: cd backend && docker-compose logs -f"
    echo ""
    echo "🛑 To Stop Everything:"
    echo "./stop.sh (or run the commands below manually)"
    echo "- Kill backend: kill $(cat backend.pid 2>/dev/null || echo 'PID_NOT_FOUND')"
    echo "- Kill frontend: kill $(cat frontend.pid 2>/dev/null || echo 'PID_NOT_FOUND')"
    echo "- Stop database: cd backend && docker-compose down"
    echo ""
}

# Create stop script
create_stop_script() {
    cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Auth Levels..."

# Stop backend
if [ -f "backend.pid" ]; then
    PID=$(cat backend.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "🔄 Stopping backend (PID: $PID)..."
        kill $PID
        rm backend.pid
    fi
fi

# Stop frontend  
if [ -f "frontend.pid" ]; then
    PID=$(cat frontend.pid)
    if kill -0 $PID 2>/dev/null; then
        echo "🔄 Stopping frontend (PID: $PID)..."
        kill $PID
        rm frontend.pid
    fi
fi

# Stop database
echo "🔄 Stopping database..."
cd backend
docker-compose down
cd ..

echo "✅ All services stopped!"
EOF
    chmod +x stop.sh
    echo "✅ Created stop.sh script"
}

# Main execution flow
main() {
    check_requirements
    setup_environment
    start_database
    setup_backend
    setup_frontend
    create_stop_script
    start_applications
    show_status
}

# Run main function
main

echo "🚀 Ready to go! Visit http://localhost:3000 to get started." 