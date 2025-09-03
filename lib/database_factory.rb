require_relative 'database'
require_relative 'mongo_database'

# Load .env file if it exists
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv not available, skip
end

class DatabaseFactory
  def self.create
    db_type = ENV['DATABASE_TYPE'] || 'sqlite'
    
    case db_type.downcase
    when 'mongodb', 'mongo'
      mongodb_uri = ENV['MONGODB_URI']
      mongodb_username = ENV['MONGODB_USERNAME']  
      mongodb_password = ENV['MONGODB_PASSWORD']
      mongodb_database = ENV['MONGODB_DATABASE']
      
      if !mongodb_uri || !mongodb_password || !mongodb_username
        puts "⚠️  MongoDB selected but missing configuration!"
        puts "   Required: MONGODB_URI, MONGODB_USERNAME, MONGODB_PASSWORD"
        puts "   Optional: MONGODB_DATABASE"
        puts "   Falling back to SQLite..."
        GymDatabase.new('data/gym_usage.db')
      else
        puts "🍃 Using MongoDB Atlas"
        MongoDatabase.new(mongodb_uri, mongodb_username, mongodb_password, mongodb_database)
      end
      
    when 'sqlite', 'sql'
      puts "🗄️  Using SQLite"
      GymDatabase.new('data/gym_usage.db')
      
    else
      puts "❌ Unknown database type: #{db_type}"
      puts "   Supported: sqlite, mongodb"
      puts "   Falling back to SQLite..."
      GymDatabase.new('data/gym_usage.db')
    end
  end
  
  def self.database_type
    ENV['DATABASE_TYPE'] || 'sqlite'
  end
end