require 'active_record'
require 'sqlite3'
require 'logger'

ActiveRecord::Base.logger = Logger.new('debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read('database.yml'))
ActiveRecord::Base.establish_connection('development')

class Address < ActiveRecord::Base
  def self.from_imap_address(address)
    self.where(:name => address.name, :address => "#{address.mailbox}@#{address.host}", :host => address.host).first_or_create
  end

  def self.from_string(address)
    name, host = address.split(/@/, 2)
    self.where(:name => address, :address => address, :host => host)
  end
end

class MessageAssociation < ActiveRecord::Base
  belongs_to :message
  belongs_to :address
end

class Message < ActiveRecord::Base
  has_many :message_associations
  # has_many :senders, :class_name => Address, :through => :message_associates, :source => :address, :finder_sql
  # has_many :to, :class_name => Address, :through => :message_associates, :source => :address
  # has_many :cc, :class_name => Address, :through => :message_associates, :source => :address
end

class Account < ActiveRecord::Base
  has_many :messages

  def message_loaded_count
    @message_loaded_count ||= Message.count
  end
end

class Token < ActiveRecord::Base; end
