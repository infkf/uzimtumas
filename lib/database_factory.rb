require_relative 'database'

# Load .env file if it exists
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # dotenv not available, skip
end

class DatabaseFactory
  def self.create
    puts "🗄️  Using SQLite"
    GymDatabase.new('data/gym_usage.db')
  end

  def self.database_type
    'sqlite'
  end
end