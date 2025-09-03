# Lemon Gym Scraper

Scrapes gym usage data from Lemon Gym Lithuania and stores it in SQLite or MongoDB.

## Quick Start

### Local Development

```bash
# Install dependencies
bundle install

# Run scraper once
ruby bin/lemon_gym_scraper.rb

# Save to database
ruby bin/lemon_gym_scraper.rb --save-to-db

# Generate report
ruby lib/gym_report.rb

# Clean old data
ruby lib/cleanup_db.rb
```

### Docker Deployment

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

## Database Configuration

### SQLite (Default)
```bash
export DATABASE_TYPE=sqlite
# Data stored in data/gym_usage.db
```

### MongoDB Atlas
```bash
export DATABASE_TYPE=mongodb
# Connection string from Atlas (with placeholders)
export MONGODB_URI="mongodb+srv://<username>:<db_password>@cluster0.oi3agb.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
# Your credentials (will replace placeholders in URI)
export MONGODB_USERNAME="igor"
export MONGODB_PASSWORD="your_actual_password"
export MONGODB_DATABASE="gym_scraper"
```

Copy `.env.example` to `.env` and configure your database settings.

## Database Management

Use the cleanup script to manage old data:

```bash
# Show database statistics
ruby lib/cleanup_db.rb stats

# Clean data older than 7 days (default)
ruby lib/cleanup_db.rb cleanup

# Clean data older than 14 days
ruby lib/cleanup_db.rb cleanup 14

# Docker version
docker-compose exec gym-scraper ruby lib/cleanup_db.rb stats
```

## Scheduling

The containerized version runs automatically:
- Every 30 minutes: Scrapes gym usage data
- Daily at 11:30 PM: Generates usage report

Use the cleanup script to remove old data:
```bash
ruby lib/cleanup_db.rb cleanup 30  # Remove data older than 30 days
```

## File Structure

```
├── bin/
│   ├── lemon_gym_scraper.rb  # Main scraper script
│   └── setup_cron.rb         # Cron setup helper
├── lib/
│   ├── database.rb           # Database handling
│   ├── gym_report.rb         # Report generation
│   └── cleanup_db.rb         # Database cleanup
├── config/
│   └── schedule.rb           # Whenever gem schedule
├── Dockerfile                # Container definition
├── docker-compose.yml        # Deployment configuration
├── data/                     # Database storage (persistent)
└── logs/                     # Application logs (persistent)
```

## Server Deployment

### Option 1: SQLite (Local Database)
1. Clone this repository to your server
2. Ensure Docker and Docker Compose are installed
3. Run: `docker-compose up -d`
4. Data persists in `./data/` and logs in `./logs/`

### Option 2: MongoDB Atlas (Cloud Database)
1. Clone this repository to your server
2. Copy `.env.example` to `.env` and configure MongoDB settings:
   ```bash
   DATABASE_TYPE=mongodb
   MONGODB_URI=mongodb+srv://<username>:<db_password>@cluster0.oi3agb.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
   MONGODB_USERNAME=igor
   MONGODB_PASSWORD=your_actual_password
   MONGODB_DATABASE=gym_scraper
   ```
3. Run: `docker-compose up -d`
4. Data stored in MongoDB Atlas, logs in `./logs/`

The container will automatically restart unless stopped manually.

## Monitoring

- Check container status: `docker-compose ps`
- View logs: `docker-compose logs -f`
- Access database stats: `docker-compose exec gym-scraper ruby lib/cleanup_db.rb stats`