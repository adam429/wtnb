require 'action_view'
require 'awesome_print'
require 'mysql2'
require 'goldiloader'
require 'securerandom'
require 'json'
require 'rails/engine'
require 'chartkick'
require 'histogram/array'

require_relative 'database'
require_relative 'wtmodel'
require_relative 'wthistory'
require_relative 'view'
require_relative 'wtbms'

module WTCube
  class Database
    class << self
      def init()
        @target= "online"
      end
      attr_accessor :target
    end
    self.init()
  end

  def history_database_config
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
        reconnect: true,
        pool: 50
    }
  end

  def online_database_config
    dbhost = "rm-8vbtg4245h6l1l01ago.mysql.zhangbei.rds.aliyuncs.com"
    dbname = "wetry"
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
        reconnect: true,
        pool: 50
    }
  end

  def connect_db(target="default")
    target=Database.target  if target=="default"
    if target=="history"
      ActiveRecord::Base.establish_connection(history_database_config)
      Database.target = "history"
    end

    if target=="online"
      ActiveRecord::Base.establish_connection(online_database_config)
      Database.target = "online"
    end

    return target
  end
end

# Log ActiveRecord SQL
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Disable Warning
Warning[:deprecated] = false

# Load WTCube into main space
include WTCube

# Connect database
connect_db()

# Load ActionView Helper
include ActionView::Helpers::NumberHelper

include Chartkick::Helper
