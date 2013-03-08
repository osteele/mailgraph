require 'active_record'
require 'sqlite3'
require 'logger'

ActiveRecord::Base.logger = Logger.new('debug.log')
ActiveRecord::Base.configurations = YAML::load(IO.read('database.yml'))
ActiveRecord::Base.establish_connection('development')

class Schema < ActiveRecord::Migration
  def change
    create_table :addresses do |t|
      t.string :name
      t.string :address
      t.string :host
    end

    add_index :addresses, :address
    add_index :addresses, :host
    add_index :addresses, [:name, :address]

    create_table :messages do |t|
      t.integer :uid
      t.integer :sender_id, :null => false, :references => [:addresses, :id]
      t.string :subject
      t.datetime :date
    end

    add_index :messages, :uid
    add_index :messages, :sender_id
    add_index :messages, :date

    create_table :message_recipients, :id => false do |t|
      t.integer :message_id, :null => false, :references => [:students, :id]
      t.integer :recipient_id, :null => false, :references => [:students, :id]
    end

    add_index :message_recipients, :message_id
    add_index :message_recipients, :recipient_id
  end
end

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
