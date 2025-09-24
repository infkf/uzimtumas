# Uzimtumas

Scrapes Vilnius gym usage data and stores it in SQLite.

## Tasks

```bash
rake scrape    # Scrape data and save to database
rake show      # Show 24h usage data for all gyms
rake cleanup   # Clean old data (default: 7 days)
rake schedule  # Run scraper every 30 minutes
```

## Local Development

```bash
bundle install
rake scrape
```

## Server Deployment

### 1. GitHub Setup

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `HOST`: Your server IP/domain
- `USERNAME`: SSH username
- `SSH_KEY`: Private SSH key content

### 2. Deploy

Push to `main` branch → GitHub Actions handles everything automatically:
- Installs Docker if needed
- Clones/updates repository
- Builds and starts container

Or deploy manually:
```bash
git pull
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Server Management

Once connected via SSH:

```bash
cd /app/uzimtumas

# Manual scrape
docker-compose exec uzimtumas-scraper rake scrape

# Show 24h data
docker-compose exec uzimtumas-scraper rake show

# Clean old data
docker-compose exec uzimtumas-scraper rake cleanup

# Clean data older than 30 days
docker-compose exec uzimtumas-scraper rake cleanup[30]

# View logs
docker-compose logs -f

# Container status
docker-compose ps

# Restart scraper
docker-compose restart
```

Data persists in `./data/` and logs in `./logs/`.