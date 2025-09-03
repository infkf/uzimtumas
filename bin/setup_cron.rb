#!/usr/bin/env ruby

puts "Setting up cron jobs for Lemon Gym scraper..."
puts "Current directory: #{Dir.pwd}"

# Install the cron jobs using whenever
system("bundle exec whenever --update-crontab")

if $?.success?
  puts "✅ Cron jobs installed successfully!"
  puts
  puts "The following jobs are now scheduled:"
  puts "- Scrape gym data every 30 minutes"  
  puts "- Generate daily report at 11:30 PM"
  puts
  puts "To view current cron jobs: crontab -l"
  puts "To remove jobs: bundle exec whenever --clear-crontab"
  puts "To check logs: tail -f log/cron.log"
else
  puts "❌ Failed to install cron jobs"
  puts "You may need to run: bundle exec whenever --update-crontab manually"
end