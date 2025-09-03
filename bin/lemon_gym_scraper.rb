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
    
    @driver = Selenium::WebDriver.for(:chrome, options: options)
    @driver.manage.timeouts.implicit_wait = 10
  end

  def scrape_club_usage
    @driver.get('https://www.lemongym.lt/klubu-uzimtumas/')
    sleep(5) # Wait for dynamic content to load
    
    # Extract structured club data
    script = <<~JS
      const clubs = [];
      const bodyText = document.body.innerText;
      const lines = bodyText.split('\\n').map(line => line.trim()).filter(line => line.length > 0);
      
      let currentCity = '';
      let i = 0;
      
      while (i < lines.length) {
        const line = lines[i];
        
        // Detect city headers
        if (line.includes('KLUBAI') && !line.includes('Visi klubai')) {
          currentCity = line.replace(' KLUBAI', '').replace(/Ų$/, 'US');
          i++;
          continue;
        }
        
        // Look for gym name followed by address and percentage
        if (line && !line.match(/^\\d+%$/) && line.length > 2) {
          let j = i + 1;
          let address = '';
          let percentage = '';
          
          // Look ahead for address and percentage
          while (j < lines.length && j < i + 4) {
            const nextLine = lines[j];
            
            if (nextLine.match(/^\\d+%$/)) {
              percentage = nextLine;
              break;
            } else if (nextLine.match(/g\\.|pr\\.|al\\.|[0-9]/) && !address) {
              address = nextLine;
            }
            j++;
          }
          
          // Only include if we found a percentage and it's a valid gym name
          if (percentage && 
              !line.match(/klubai|tapti|visi|©/i) &&
              !line.match(/^[A-ZŠŽČĄĘĮ\\s.,0-9]+$/)) {
            
            clubs.push({
              city: currentCity,
              name: line,
              address: address,
              usage: percentage
            });
          }
        }
        i++;
      }
      
      return clubs;
    JS
    
    club_data = @driver.execute_script(script)
    
    # Clean and deduplicate
    clean_data = club_data
      .map { |club| clean_club_data(club) }
      .select { |club| valid_club?(club) }
      .reject { |club| club[:usage] == 100 } # Skip 100% usage (indicates no real data)
      .uniq { |club| [normalize_name(club[:name]), club[:city]] }
    
    clean_data
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

  def normalize_name(name)
    name.gsub(/[^A-ZŠŽČĄĘĮ0-9]/, '')
  end

  def valid_club?(club)
    club[:name].length > 2 && 
    club[:usage] > 0 && 
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