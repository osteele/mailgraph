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

class MessageRecipient < ActiveRecord::Base
  belongs_to :message
  belongs_to :recipient, :class_name => Address
end

class Message < ActiveRecord::Base
  has_one :sender, :class_name => Address
  has_many :message_recipients
  has_many :recipients, :class_name => Address, :through => :message_recipients#, :foreign_key => :recipient_id
  # has_many :links, :dependent => destroy
end

class Account < ActiveRecord::Base
  def message_loaded_count
    @message_loaded_count ||= Message.count
  end
end

class Token < ActiveRecord::Base
end
