#!/usr/bin/env ruby

require_relative 'database_factory'

class GymReporter
  def initialize
    @db = DatabaseFactory.create
  end

  def generate_daily_report
    puts "📊 Daily Gym Usage Report - #{Date.today}"
    puts "=" * 50
    
    latest_data = @db.get_latest_data
    
    if latest_data.empty?
      puts "❌ No data available"
      return
    end
    
    # Handle both SQLite and MongoDB data formats
    first_record = latest_data.first
    timestamp = first_record['timestamp'] || first_record[:timestamp]
    
    puts "🕒 Latest reading: #{timestamp}"
    puts
    
    # Group by city - handle both formats
    by_city = latest_data.group_by { |row| 
      row['city'] || row[:city] 
    }
    
    by_city.each do |city, gyms|
      next if city.nil? || city.empty?
      
      puts "📍 #{city.upcase}"
      puts "-" * 30
      
      sorted_gyms = gyms.sort_by { |gym| 
        -(gym['usage_percentage'] || gym[:usage_percentage])
      }
      
      sorted_gyms.each do |gym|
        usage = gym['usage_percentage'] || gym[:usage_percentage]
        name = gym['gym_name'] || gym[:gym_name]
        usage_bar = create_usage_bar(usage)
        puts "#{name.ljust(25)} #{usage.to_s.rjust(3)}% #{usage_bar}"
      end
      puts
    end
    
    # Weekly stats
    puts "📈 7-Day Statistics"
    puts "-" * 30
    
    stats = @db.get_usage_stats(7)
    
    if stats.any?
      puts "Top 5 Busiest (Avg):"
      stats.first(5).each_with_index do |gym, index|
        puts "  #{index + 1}. #{gym[:gym_name]} - #{gym[:avg_usage]}% avg"
      end
      
      puts "\nTop 5 Quietest (Avg):"
      stats.last(5).reverse.each_with_index do |gym, index|
        puts "  #{index + 1}. #{gym[:gym_name]} - #{gym[:avg_usage]}% avg"
      end
    end
    
    # Hourly peak analysis
    puts "\n🕒 Peak Hours Analysis (7-Day Average)"
    puts "-" * 50
    
    hourly_stats = @db.get_hourly_usage_stats(7)
    
    if hourly_stats.any?
      by_city_hourly = hourly_stats.group_by { |gym| gym[:city] }
      
      by_city_hourly.each do |city, gyms|
        next if city.nil? || city.empty?
        
        puts "\n📍 #{city.upcase} - PEAK HOURS"
        puts "-" * 35
        
        gyms.sort_by { |gym| -(gym[:peak_usage] || 0) }.each do |gym|
          if gym[:peak_hour] && gym[:peak_usage]
            peak_time = format_hour(gym[:peak_hour])
            quiet_time = format_hour(gym[:quiet_hour])
            puts "#{gym[:gym_name].ljust(25)} 🔥 #{peak_time} (#{gym[:peak_usage]}%) 😴 #{quiet_time} (#{gym[:quiet_usage]}%)"
          end
        end
      end
    else
      puts "❌ Not enough data for hourly analysis"
    end
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