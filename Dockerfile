FROM ruby:3.2

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    cron \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Chrome directly
RUN wget -q -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y ./chrome.deb || apt-get install -yf \
    && rm chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# Install ChromeDriver
RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1-3) \
    && wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" \
    && unzip /tmp/chromedriver.zip -d /tmp/ \
    && mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/ \
    && chmod +x /usr/local/bin/chromedriver \
    && rm -rf /tmp/chromedriver*

WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application
COPY . .

# Create data directory
RUN mkdir -p data logs

# Set timezone
ENV TZ=Europe/Vilnius

# Run scheduler by default
CMD ["rake", "schedule"]