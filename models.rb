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

  def self.combine_addresses!
    Address.connection.execute <<-SQL
      UPDATE addresses
      SET person_id = (SELECT (CASE WHEN ad.person_id THEN ad.person_id ELSE ad.id END) AS pid FROM addresses AS ad WHERE ad.address = addresses.address ORDER BY pid LIMIT 1)
      WHERE person_id IS NULL
    SQL
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

  def frequent_correspondents(limit=nil)
    limit ||= 15
    addresses = Address.find_by_sql([<<-"SQL", self.id, self.id, limit])
      SELECT (CASE WHEN person_id THEN person_id ELSE addresses.id END) AS id, COUNT(*) AS count FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.account_id = ?
      AND HOST IS NOT NULL
      AND (person_id IS NULL OR person_id != ?)
      GROUP BY id
      ORDER BY COUNT(*) DESC
      LIMIT ?
    SQL
    Address.find(addresses.map(&:id))
  end
end

class Token < ActiveRecord::Base; end
