FROM ruby:3.2

# Install Chromium and dependencies
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    cron \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile ./
RUN bundle install

# Copy application
COPY . .

# Create data directory
RUN mkdir -p data logs

# Set timezone
ENV TZ=Europe/Vilnius

# Run scheduler by default
CMD ["rake", "schedule"]