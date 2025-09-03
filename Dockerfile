FROM ruby:3.2-alpine

# Install dependencies for Chrome and build tools
RUN apk add --no-cache \
    chromium \
    chromium-chromedriver \
    build-base \
    sqlite-dev \
    tzdata \
    dcron \
    bash

# Set Chrome path for Selenium
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROMEDRIVER_PATH=/usr/bin/chromedriver

# Set timezone
ENV TZ=Europe/Vilnius
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create app directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN gem install sqlite3 --platform ruby -- --with-sqlite3-include=/usr/include --with-sqlite3-lib=/usr/lib
RUN bundle install --without development test

# Set default database type (can be overridden with environment variables)
ENV DATABASE_TYPE=sqlite

# Copy application files
COPY . .

# Create directories for logs and database
RUN mkdir -p logs data
RUN chmod +x bin/lemon_gym_scraper.rb lib/gym_report.rb lib/cleanup_db.rb

# Create volume for persistent data
VOLUME ["/app/data", "/app/logs"]

# Set up cron using whenever gem
RUN bundle exec whenever --update-crontab

# Start cron and keep container running
CMD ["sh", "-c", "crond && tail -f /dev/null"]