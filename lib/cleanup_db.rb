#!/usr/bin/env ruby

require_relative 'database_factory'

class DatabaseCleaner
  def initialize
    @db = DatabaseFactory.create
  end

  def cleanup_old_data(days_to_keep = 7)
    puts "🧹 Starting database cleanup..."
    puts "Removing data older than #{days_to_keep} days"
    
    @db.cleanup_old_data(days_to_keep)
  end

  def show_database_stats
    if @db.respond_to?(:get_database_stats)
      # MongoDB
      stats = @db.get_database_stats
      daily_stats = stats[:daily_stats]
      
      puts "\n📊 Database Statistics (Last 10 days):"
      puts "-" * 50
      
      if daily_stats.empty?
        puts "No data found in database"
      else
        daily_stats.each do |row|
          date = row['_id']
          readings = row['readings']
          first = row['first_reading'].strftime('%Y-%m-%d %H:%M:%S')
          last = row['last_reading'].strftime('%Y-%m-%d %H:%M:%S')
          puts "#{date}: #{readings} readings (#{first} - #{last})"
        end
      end
      
      puts "\n📈 Total Records: #{stats[:total_records]}"
      puts "🕒 Oldest Record: #{stats[:oldest_record]&.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "🕒 Newest Record: #{stats[:newest_record]&.strftime('%Y-%m-%d %H:%M:%S')}"
      
    else
      # SQLite
      stats = @db.db.execute(<<-SQL)
        SELECT 
          DATE(timestamp) as date,
          COUNT(*) as readings,
          MIN(timestamp) as first_reading,
          MAX(timestamp) as last_reading
        FROM gym_usage 
        GROUP BY DATE(timestamp) 
        ORDER BY date DESC 
        LIMIT 10
      SQL

      puts "\n📊 Database Statistics (Last 10 days):"
      puts "-" * 50
      
      if stats.empty?
        puts "No data found in database"
      else
        stats.each do |row|
          puts "#{row['date']}: #{row['readings']} readings (#{row['first_reading']} - #{row['last_reading']})"
        end
      end

      total_records = @db.db.execute("SELECT COUNT(*) as count FROM gym_usage").first['count']
      oldest_record = @db.db.execute("SELECT MIN(timestamp) as oldest FROM gym_usage").first['oldest']
      newest_record = @db.db.execute("SELECT MAX(timestamp) as newest FROM gym_usage").first['newest']
      
      puts "\n📈 Total Records: #{total_records}"
      puts "🕒 Oldest Record: #{oldest_record}"
      puts "🕒 Newest Record: #{newest_record}"
    end
  end

  def close
    @db.close
  end
end

# Command line interface
if __FILE__ == $0
  case ARGV[0]
  when 'stats', '--stats', '-s'
    cleaner = DatabaseCleaner.new
    begin
      cleaner.show_database_stats
    ensure
      cleaner.close
    end
    
  when 'cleanup', '--cleanup', '-c', nil
    days = (ARGV[1] || '7').to_i
    cleaner = DatabaseCleaner.new
    begin
      cleaner.cleanup_old_data(days)
      cleaner.show_database_stats
    ensure
      cleaner.close
    end
    
  when 'help', '--help', '-h'
    puts <<~HELP
      Database Cleanup Tool for Lemon Gym Scraper
      
      Usage:
        ruby cleanup_db.rb [command] [options]
      
      Commands:
        cleanup [days]  Clean up data older than N days (default: 7)
        stats           Show database statistics
        help            Show this help message
      
      Examples:
        ruby cleanup_db.rb                # Clean data older than 7 days
        ruby cleanup_db.rb cleanup 14     # Clean data older than 14 days
        ruby cleanup_db.rb stats          # Show database statistics
    HELP
    
  else
    puts "Unknown command: #{ARGV[0]}"
    puts "Use 'ruby cleanup_db.rb help' for usage information"
  end
end