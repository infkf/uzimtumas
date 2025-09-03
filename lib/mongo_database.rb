require 'mongo'
require 'time'

class MongoDatabase
  def initialize(connection_string = nil, username = nil, password = nil, database_name = nil)
    @connection_string = connection_string || ENV['MONGODB_URI'] || 'mongodb://localhost:27017'
    @username = username || ENV['MONGODB_USERNAME']
    @password = password || ENV['MONGODB_PASSWORD']
    @database_name = database_name || ENV['MONGODB_DATABASE'] || 'gym_scraper'
    
    setup_connection
  end

  def setup_connection
    begin
      # Replace placeholders in connection string
      connection_string = @connection_string
      connection_string = connection_string.gsub('<db_password>', @password) if @password
      connection_string = connection_string.gsub('<username>', @username) if @username
      
      database_name = @database_name
      
      # Setup client options
      client_options = { 
        database: database_name,
        connect_timeout: 10,
        socket_timeout: 10,
        server_selection_timeout: 10,
        max_pool_size: 5
      }
      
      # Handle SRV connection strings
      if connection_string.start_with?('mongodb+srv://')
        # For Atlas SRV URIs, the auth source is typically 'admin'
        # unless it's in the connection string already
        if !connection_string.include?('authSource=')
          client_options[:auth_source] = 'admin'
        end
        @client = Mongo::Client.new(connection_string, client_options)
      else
        # For regular mongodb:// URIs, parse first
        uri = Mongo::URI.new(connection_string)
        
        # Use specified database name, fallback to URI database, then default
        if database_name == 'gym_scraper' && uri.database
          database_name = uri.database
          client_options[:database] = database_name
        end
        
        # Add authentication if provided and not already in connection string
        if @username && @password && !connection_string.include?(@username)
          client_options[:user] = @username
          client_options[:password] = @password
          client_options[:auth_source] = 'admin'
        end
        
        @client = Mongo::Client.new(connection_string, client_options)
      end
      
      @collection = @client[:gym_usage]
      
      # Test the connection
      @client.database.command(ping: 1)
      
      puts "✅ Connected to MongoDB: #{database_name}"
      
    rescue => e
      puts "❌ Failed to connect to MongoDB: #{e.message}"
      puts "   Connection string: #{@connection_string.gsub(@password || '', '[REDACTED]')}"
      puts "   Database: #{@database_name}"
      raise e
    end
  end

  def save_gym_data(clubs)
    timestamp = Time.now.utc
    
    documents = clubs.map do |club|
      {
        timestamp: timestamp,
        city: club[:city],
        gym_name: club[:name],
        address: club[:address],
        usage_percentage: club[:usage],
        scraped_at: timestamp
      }
    end
    
    result = @collection.insert_many(documents)
    
    puts "✅ Saved #{result.inserted_count} gym records to MongoDB at #{timestamp.strftime('%Y-%m-%d %H:%M:%S')} UTC"
  end

  def get_latest_data
    # Get the latest timestamp
    latest_timestamp = @collection.find({}, { sort: { timestamp: -1 }, limit: 1 }).first
    return [] unless latest_timestamp
    
    # Get all records with that timestamp
    @collection.find(
      { timestamp: latest_timestamp['timestamp'] },
      { sort: { city: 1, gym_name: 1 } }
    ).to_a
  end

  def get_gym_history(gym_name, days = 7)
    start_time = Time.now.utc - (days * 24 * 60 * 60)
    
    @collection.find(
      { 
        gym_name: /#{Regexp.escape(gym_name)}/i,
        timestamp: { '$gte' => start_time }
      },
      { sort: { timestamp: -1 } }
    ).to_a
  end

  def get_usage_stats(days = 7)
    start_time = Time.now.utc - (days * 24 * 60 * 60)
    
    pipeline = [
      { '$match' => { timestamp: { '$gte' => start_time } } },
      { 
        '$group' => {
          _id: { gym_name: '$gym_name', city: '$city' },
          avg_usage: { '$avg' => '$usage_percentage' },
          min_usage: { '$min' => '$usage_percentage' },
          max_usage: { '$max' => '$usage_percentage' },
          readings_count: { '$sum' => 1 }
        }
      },
      { '$sort' => { avg_usage: -1 } }
    ]
    
    results = @collection.aggregate(pipeline).to_a
    
    results.map do |doc|
      {
        gym_name: doc['_id']['gym_name'],
        city: doc['_id']['city'],
        avg_usage: doc['avg_usage'].round(1),
        min_usage: doc['min_usage'],
        max_usage: doc['max_usage'],
        readings_count: doc['readings_count']
      }
    end
  end

  def get_hourly_usage_stats(days = 7)
    start_time = Time.now.utc - (days * 24 * 60 * 60)
    
    pipeline = [
      { '$match' => { timestamp: { '$gte' => start_time } } },
      {
        '$group' => {
          _id: { 
            gym_name: '$gym_name',
            city: '$city',
            hour: { '$hour' => '$timestamp' }
          },
          avg_usage: { '$avg' => '$usage_percentage' },
          readings_count: { '$sum' => 1 }
        }
      },
      { '$sort' => { '_id.gym_name' => 1, '_id.hour' => 1 } }
    ]
    
    results = @collection.aggregate(pipeline).to_a
    
    # Group by gym for easier processing
    grouped = {}
    results.each do |doc|
      gym_name = doc['_id']['gym_name']
      city = doc['_id']['city']
      hour = doc['_id']['hour']
      key = "#{gym_name}|#{city}"
      
      grouped[key] ||= { 
        gym_name: gym_name, 
        city: city, 
        hourly_data: {} 
      }
      grouped[key][:hourly_data][hour] = {
        avg_usage: doc['avg_usage'].round(1),
        readings_count: doc['readings_count']
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

  def cleanup_old_data(days_to_keep = 7)
    cutoff_time = Time.now.utc - (days_to_keep * 24 * 60 * 60)
    
    # Count records before cleanup
    total_before = @collection.count_documents({})
    to_delete = @collection.count_documents({ timestamp: { '$lt' => cutoff_time } })
    
    if to_delete == 0
      puts "✅ No old data to clean up"
      return { deleted: 0, total_before: total_before, total_after: total_before }
    end
    
    # Perform cleanup
    result = @collection.delete_many({ timestamp: { '$lt' => cutoff_time } })
    total_after = @collection.count_documents({})
    
    puts "✅ Cleanup complete!"
    puts "   Records before: #{total_before}"
    puts "   Records deleted: #{result.deleted_count}"
    puts "   Records remaining: #{total_after}"
    
    { deleted: result.deleted_count, total_before: total_before, total_after: total_after }
  end

  def get_database_stats
    pipeline = [
      {
        '$group' => {
          _id: { '$dateToString' => { format: '%Y-%m-%d', date: '$timestamp' } },
          readings: { '$sum' => 1 },
          first_reading: { '$min' => '$timestamp' },
          last_reading: { '$max' => '$timestamp' }
        }
      },
      { '$sort' => { _id: -1 } },
      { '$limit' => 10 }
    ]
    
    daily_stats = @collection.aggregate(pipeline).to_a
    
    total_records = @collection.count_documents({})
    oldest_record = @collection.find({}, { sort: { timestamp: 1 }, limit: 1 }).first
    newest_record = @collection.find({}, { sort: { timestamp: -1 }, limit: 1 }).first
    
    {
      daily_stats: daily_stats,
      total_records: total_records,
      oldest_record: oldest_record&.[]('timestamp'),
      newest_record: newest_record&.[]('timestamp')
    }
  end

  def close
    @client&.close
  end
end