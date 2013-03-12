require 'active_record'

RACK_ENV = ENV['RACK_ENV'] || 'development'

ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), '../debug.log')) if RACK_ENV == 'development'
ActiveRecord::Base.configurations = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.establish_connection(RACK_ENV)

# configure :production, :development do
# 	db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

# 	ActiveRecord::Base.establish_connection(
# 			:adapter => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
# 			:host     => db.host,
# 			:username => db.user,
# 			:password => db.password,
# 			:database => db.path[1..-1],
# 			:encoding => 'utf8'
# 	)
# end
