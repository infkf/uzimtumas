require_relative 'lib/database_factory'
require_relative 'lib/cleanup_db'

desc "Scrape gym usage data, save to database, and display results"
task :scrape do
  puts "🏋️  Starting gym usage scraping..."

  # Load the scraper
  require_relative 'bin/lemon_gym_scraper'

  scraper = LemonGymScraper.new
  db = nil

  begin
    clubs = scraper.scrape_club_usage

    if clubs.any?
      # Save to database
      db = DatabaseFactory.create
      db.save_gym_data(clubs)
      puts "💾 Data saved to database"
      puts

      # Pretty print results
      scraper.print_results(clubs)
    else
      puts "❌ No club data found"
    end

  ensure
    scraper.close
    db&.close
  end
end

desc "Show gym usage data for each club"
task :show do
  puts "📊 Gym Usage Report"
  puts "=" * 40

  # Load the reporter
  require_relative 'lib/gym_report'

  reporter = GymReporter.new

  begin
    reporter.generate_daily_report
  ensure
    reporter.close
  end
end

desc "Clean up old gym usage data"
task :cleanup, [:days] do |t, args|
  days = (args[:days] || '7').to_i

  puts "🧹 Cleaning up gym usage data..."

  cleaner = DatabaseCleaner.new

  begin
    cleaner.cleanup_old_data(days)
    cleaner.show_database_stats
  ensure
    cleaner.close
  end
end

desc "Run scraper every hour (blocking task)"
task :schedule do
  puts "⏰ Starting scheduled scraper (every hour)"
  puts "Press Ctrl+C to stop"

  trap("INT") do
    puts "\n🛑 Stopping scheduler..."
    exit
  end

  loop do
    puts "\n#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - Running scraper..."

    begin
      Rake::Task[:scrape].reenable
      Rake::Task[:scrape].invoke
    rescue => e
      puts "❌ Error during scraping: #{e.message}"
    end

    puts "😴 Sleeping..."
    sleep(1800)
  end
end

task default: :scrape