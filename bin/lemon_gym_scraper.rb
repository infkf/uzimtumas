#!/usr/bin/env ruby

require 'selenium-webdriver'
require_relative '../lib/database_factory'

class LemonGymScraper
  def initialize
    setup_driver
  end

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Use Chromium in Docker, Chrome locally
    if File.exist?('/usr/bin/chromium')
      options.binary = '/usr/bin/chromium'
      service = Selenium::WebDriver::Service.chrome(path: '/usr/bin/chromedriver')
      @driver = Selenium::WebDriver.for(:chrome, service: service, options: options)
    else
      @driver = Selenium::WebDriver.for(:chrome, options: options)
    end

    @driver.manage.timeouts.implicit_wait = 10
  end

  def scrape_club_usage
    @driver.get('https://www.lemongym.lt/klubu-uzimtumas/')
    sleep(5) # Wait for dynamic content to load

    # Find all club occupancy containers (includes both club info and percentage)
    occupancy_elements = @driver.find_elements(:css, '.clubs-occupancy')

    club_data = []

    occupancy_elements.each do |occupancy_element|
      begin
        # Extract gym name from h6 inside the club div
        club_element = occupancy_element.find_element(:css, '.clubs-occupancy__club')
        name_element = club_element.find_element(:css, 'h6')
        gym_name = name_element.text.strip

        # Extract address from p element
        address = ''
        begin
          address_element = club_element.find_element(:css, 'p')
          address = address_element.text.strip
        rescue
          # Address is optional
        end

        # Extract usage percentage from sibling h6 element
        usage_percentage = 0
        begin
          percentage_element = occupancy_element.find_element(:css, 'h6.clubs-occupancy__percentage')
          usage_text = percentage_element.text.match(/(\d+)%/)
          usage_percentage = usage_text ? usage_text[1].to_i : 0
        rescue
          # Skip if no percentage found
          next
        end

        # Determine city from parent sections or headers
        city = determine_city_from_element(occupancy_element)

        club_data << {
          'city' => city,
          'name' => gym_name,
          'address' => address,
          'usage' => usage_percentage
        }

      rescue => e
        # Skip problematic elements
        puts "⚠️ Skipped occupancy element: #{e.message}"
        next
      end
    end

    puts "🔍 Found #{club_data.length} clubs using CSS selectors"

    # Clean, filter Vilnius only, and remove invalid data
    club_data
      .map { |club| clean_club_data(club) }
      .select { |club| valid_club?(club) }
      .select { |club| club[:city]&.match(/VILNIUS|VILNIAUS/i) } # Only Vilnius clubs
      .reject { |club| club[:usage] == 100 } # Skip 100% usage (indicates error data)
      .uniq { |club| club[:name] } # Simple deduplication by name
  end

  def determine_city_from_element(club_element)
    # Look for city headers in parent elements
    begin
      current = club_element
      3.times do
        current = current.find_element(:xpath, '..')
        text = current.text.upcase
        return 'VILNIAUS' if text.include?('VILNIAUS') || text.include?('VILNIUS')
        return 'KAUNO' if text.include?('KAUNO') || text.include?('KAUNAS')
        return 'ŠIAULIUS' if text.include?('ŠIAULIUS')
      end
    rescue
      # Fallback
    end
    'UNKNOWN'
  end

  def clean_club_data(club)
    {
      city: club['city'],
      name: clean_name(club['name']),
      address: club['address'] || '',
      usage: club['usage'].to_i
    }
  end

  def clean_name(name)
    name.gsub(/[🥳⏳✨]/, '')
        .gsub(/\s*-\s*(jau šį rudenį|ką tik atidarytas|atnaujinamas).*$/i, '')
        .gsub(/\([^)]*\)/, '') # Remove parentheses content
        .strip
        .upcase
  end


  def valid_club?(club)
    club[:name].length > 2 &&
    club[:usage] >= 0 &&
    !club[:name].match(/^[0-9\s.,g]+$/i)
  end

  def print_results(clubs)
    return puts "❌ No club data found" if clubs.empty?
    
    puts "✅ Found #{clubs.length} Lemon Gym clubs:\n"
    
    by_city = clubs.group_by { |club| club[:city] }
    
    by_city.each do |city, city_clubs|
      next if city.empty?
      
      puts "📍 #{city}"
      puts "─" * 35
      
      city_clubs.sort_by { |club| -club[:usage] }.each do |club|
        bar = create_usage_bar(club[:usage])
        puts "#{club[:name].ljust(20)} #{club[:usage].to_s.rjust(3)}% #{bar}"
        puts "   #{club[:address]}" unless club[:address].empty?
      end
      puts
    end
    
    print_summary(clubs)
  end

  def create_usage_bar(usage)
    filled = (usage / 5).to_i
    "█" * filled + "░" * [0, 20 - filled].max
  end

  def print_summary(clubs)
    avg = clubs.map { |c| c[:usage] }.sum / clubs.length.to_f
    busiest = clubs.max_by { |c| c[:usage] }
    quietest = clubs.select { |c| c[:usage] > 0 }.min_by { |c| c[:usage] }
    
    puts "📊 Average usage: #{avg.round(1)}%"
    puts "🔥 Busiest: #{busiest[:name]} (#{busiest[:usage]}%)" if busiest
    puts "😌 Quietest: #{quietest[:name]} (#{quietest[:usage]}%)" if quietest
  end

  def close
    @driver&.quit
  end
end

if __FILE__ == $0
  save_to_db = ARGV.include?('--save-to-db')
  scraper = LemonGymScraper.new
  db = nil
  
  begin
    puts "🏋️  Lemon Gym Club Usage Scraper"
    puts "=" * 40
    
    clubs = scraper.scrape_club_usage
    
    if save_to_db
      db = DatabaseFactory.create
      db.save_gym_data(clubs)
      puts "💾 Data saved to database"
    else
      scraper.print_results(clubs)
    end
    
  ensure
    scraper.close
    db&.close
  end
end