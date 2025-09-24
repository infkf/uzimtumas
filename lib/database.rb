require 'sqlite3'
require 'time'

class GymDatabase
  attr_reader :db
  
  def initialize(db_path = 'data/gym_usage.db')
    @db_path = db_path
    # Ensure data directory exists
    dir = File.dirname(@db_path)
    Dir.mkdir(dir) unless Dir.exist?(dir)
    
    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    setup_database
  end

  def setup_database
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS gym_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        city TEXT NOT NULL,
        gym_name TEXT NOT NULL,
        address TEXT,
        usage_percentage INTEGER NOT NULL,
        scraped_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    @db.execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_gym_timestamp ON gym_usage(gym_name, timestamp)
    SQL

    @db.execute <<-SQL
      CREATE INDEX IF NOT EXISTS idx_city_timestamp ON gym_usage(city, timestamp)
    SQL
  end

  def save_gym_data(clubs)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    
    @db.transaction do
      clubs.each do |club|
        @db.execute(
          "INSERT INTO gym_usage (timestamp, city, gym_name, address, usage_percentage) VALUES (?, ?, ?, ?, ?)",
          [timestamp, club[:city], club[:name], club[:address], club[:usage]]
        )
      end
    end
    
    puts "✅ Saved #{clubs.length} gym records to database at #{timestamp}"
  end

  def get_latest_data
    @db.execute(
      "SELECT * FROM gym_usage WHERE timestamp = (SELECT MAX(timestamp) FROM gym_usage) ORDER BY city, gym_name"
    )
  end

  def get_24hour_data
    @db.execute(
      "SELECT
        gym_name,
        strftime('%H:%M', timestamp) as time,
        usage_percentage,
        timestamp
      FROM gym_usage
      WHERE timestamp >= datetime('now', '-1 day')
      ORDER BY gym_name, timestamp"
    )
  end

  def get_gym_history(gym_name, days = 7)
    @db.execute(
      "SELECT * FROM gym_usage WHERE gym_name LIKE ? AND timestamp >= datetime('now', '-#{days} days') ORDER BY timestamp DESC",
      ["%#{gym_name}%"]
    )
  end

  def get_usage_stats(days = 7)
    stats = @db.execute(
      "SELECT 
        gym_name,
        city,
        AVG(usage_percentage) as avg_usage,
        MIN(usage_percentage) as min_usage,
        MAX(usage_percentage) as max_usage,
        COUNT(*) as readings_count
      FROM gym_usage 
      WHERE timestamp >= datetime('now', '-#{days} days')
      GROUP BY gym_name, city 
      ORDER BY avg_usage DESC"
    )
    
    stats.map do |row|
      {
        gym_name: row['gym_name'],
        city: row['city'],
        avg_usage: row['avg_usage'].round(1),
        min_usage: row['min_usage'],
        max_usage: row['max_usage'],
        readings_count: row['readings_count']
      }
    end
  end

  def get_hourly_usage_stats(days = 7)
    stats = @db.execute(
      "SELECT 
        gym_name,
        city,
        strftime('%H', timestamp) as hour,
        AVG(usage_percentage) as avg_usage,
        COUNT(*) as readings_count
      FROM gym_usage 
      WHERE timestamp >= datetime('now', '-#{days} days')
      GROUP BY gym_name, city, strftime('%H', timestamp)
      ORDER BY gym_name, hour"
    )
    
    # Group by gym for easier processing
    grouped = {}
    stats.each do |row|
      key = "#{row['gym_name']}|#{row['city']}"
      grouped[key] ||= { 
        gym_name: row['gym_name'], 
        city: row['city'], 
        hourly_data: {} 
      }
      grouped[key][:hourly_data][row['hour'].to_i] = {
        avg_usage: row['avg_usage'].round(1),
        readings_count: row['readings_count']
      }
    end
    
    # Add peak hour analysis
    grouped.each do |key, data|
      if data[:hourly_data].any?
        peak_hour = data[:hourly_data].max_by { |hour, stats| stats[:avg_usage] }
        quiet_hour = data[:hourly_data].min_by { |hour, stats| stats[:avg_usage] }
        
        data[:peak_hour] = peak_hour[0]
        data[:peak_usage] = peak_hour[1][:avg_usage]
        data[:quiet_hour] = quiet_hour[0]
        data[:quiet_usage] = quiet_hour[1][:avg_usage]
      end
    end
    
    grouped.values
  end

  def cleanup_old_data(days_to_keep = 30)
    deleted = @db.execute(
      "DELETE FROM gym_usage WHERE timestamp < datetime('now', '-#{days_to_keep} days')"
    )
    
    puts "🧹 Cleaned up old data (#{@db.changes} records deleted)"
  end

  def close
    @db.close
  end
end