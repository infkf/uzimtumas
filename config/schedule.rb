# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

set :output, -> { File.exist?('/app') ? "/app/logs/cron.log" : "#{Dir.pwd}/logs/cron.log" }
set :environment_variable, "PATH"

# Learn more: http://github.com/javan/whenever

# Determine paths based on environment
def get_base_path
  File.exist?('/app') ? '/app' : Dir.pwd
end

def get_log_path
  base = get_base_path
  "#{base}/logs"
end

# Scrape gym data every 30 minutes (24/7 - gyms are open 24h)
every 30.minutes, at: [0, 30] do
  base_path = get_base_path
  log_path = get_log_path
  command "cd #{base_path} && ruby bin/lemon_gym_scraper.rb --save-to-db >> #{log_path}/scraper.log 2>&1"
end

# Generate daily summary report at 11:30 PM
every :day, at: '11:30 pm' do
  base_path = get_base_path
  log_path = get_log_path
  command "cd #{base_path} && ruby lib/gym_report.rb >> #{log_path}/report.log 2>&1"
end