# Gemini Workspace

## Project Overview

This project is a Ruby application designed to scrape gym usage data from the Lemon Gym Lithuania website. It is containerized using Docker for easy deployment and automated execution.

### Key Features

- **Web Scraping**: Uses `selenium-webdriver` to scrape live gym usage data.
- **Database Support**: Uses SQLite for local data storage.
- **Containerization**: Fully containerized with Docker, including a cron-based scheduler.
- **Data Processing**: Cleans and processes the scraped data, filtering out invalid readings.
- **Reporting**: Can generate reports on gym usage.
- **Scheduled Jobs**:
    - Scrapes gym data every 30 minutes.
    - Generates a daily report at 11:30 PM.

## Project Structure

- `bin/lemon_gym_scraper.rb`: The main scraper script.
- `lib/`: Contains the core application logic.
    - `lib/database.rb`: SQLite database implementation.
    - `lib/database_factory.rb`: Factory for creating database instances.
    - `lib/gym_report.rb`: Script for generating reports.
    - `lib/cleanup_db.rb`: Script for cleaning up old data.
- `config/schedule.rb`: Defines the cron jobs using the `whenever` gem.
- `Dockerfile`: Defines the Docker image for the application.
- `docker-compose.yml`: Configures the Docker services.
- `data/`: Directory for the SQLite database file.
- `logs/`: Directory for application and cron logs.

## How it Works

1.  The `docker-compose up -d` command builds and starts the `gym-scraper` service.
2.  The `Dockerfile` sets up a Ruby environment, installs dependencies, and configures two cron jobs.
3.  The cron jobs execute `bin/lemon_gym_scraper.rb` and `lib/gym_report.rb` at their scheduled times.
4.  The `lemon_gym_scraper.rb` script launches a headless Chrome browser, navigates to the Lemon Gym website, and scrapes the gym usage data.
5.  The `DatabaseFactory` class creates a SQLite database instance.
6.  The scraped data is saved to the SQLite database.

## Development Notes

- To run the scraper locally: `ruby bin/lemon_gym_scraper.rb`
- To save data to the database locally: `ruby bin/lemon_gym_scraper.rb --save-to-db`
- Database is automatically created in the `data/` directory.
- The `whenever` gem can be used to update the cron jobs in `config/schedule.rb`.