#!/usr/bin/env ruby

require_relative 'database_factory'

class GymReporter
  def initialize
    @db = DatabaseFactory.create
  end

  def generate_daily_report
    puts "📊 Last 24 Hours Gym Usage - #{Date.today}"
    puts "=" * 60

    data_24h = @db.get_24hour_data

    if data_24h.empty?
      puts "❌ No data available for the last 24 hours"
      return
    end

    # Group by gym name
    by_gym = data_24h.group_by { |row| row['gym_name'] }

    by_gym.each do |gym_name, readings|
      puts "\n#{gym_name}:"
      readings.each do |reading|
        puts "\t#{reading['time']}\t#{reading['usage_percentage']}%"
      end
    end

    puts "\n📈 Summary: #{by_gym.keys.length} gyms, #{data_24h.length} total readings"
  end

  def create_usage_bar(usage)
    filled = (usage / 5).to_i
    "█" * filled + "░" * [0, 20 - filled].max
  end

  def format_hour(hour)
    case hour
    when 0..11
      hour == 0 ? "12:00 AM" : "#{hour}:00 AM"
    when 12
      "12:00 PM"
    else
      "#{hour - 12}:00 PM"
    end
  end

  def close
    @db.close
  end
end

if __FILE__ == $0
  reporter = GymReporter.new
  
  begin
    reporter.generate_daily_report
  ensure
    reporter.close
  end
end