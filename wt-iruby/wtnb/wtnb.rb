require 'action_view'
require 'awesome_print'
require 'mysql2'
require 'goldiloader'
require 'securerandom'
require 'json'

require_relative 'database'
require_relative 'wtmodel'
require_relative 'wthistory'
require_relative 'view'

module WTCube
  def database_config
    dbhost = "rm-uf62z5du2b5o091gp2o.mysql.rds.aliyuncs.com"
    dbname = "wetrydb"
    dbusername = "libo"
    dbpassword = '%e$j2uUgPdWwJ#Y8'

    database = {
        adapter: 'mysql2',
        host: dbhost,
        database: dbname,
        connect_timeout: '5',
        port: '3306',
        username: dbusername,
        password: dbpassword,
        reconnect: true
    }
  end
end

# Log ActiveRecord SQL
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Disable Warning
Warning[:deprecated] = false

# Load WTCube into main space
include WTCube

# Connect database
ActiveRecord::Base.establish_connection(database_config)

# Load ActionView Helper
include ActionView::Helpers::NumberHelper
