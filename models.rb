class Address < ActiveRecord::Base
  def self.from_imap_address(address)
    self.where(:display_name => address.name, :spec => "#{address.mailbox}@#{address.host}", :domain_name => address.host).first_or_create
  end

  def self.from_string(address)
    name, domain_name = address.split(/@/, 2)
    self.where(:display_name => address, :spec => address, :domain_name => domain_name)
  end

  def self.combine_addresses!
    Address.connection.execute <<-SQL
      UPDATE addresses
      SET canonical_address_id = (SELECT (CASE WHEN ad.canonical_address_id THEN ad.canonical_address_id ELSE ad.id END) AS pid FROM addresses AS ad WHERE ad.spec = addresses.spec ORDER BY pid LIMIT 1)
      WHERE canonical_address_id IS NULL
    SQL
  end

  def canonicalize
    return Address.find(canonical_address_id) if canonical_address_id and canonical_address_id != id
    return self
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
    account_address = Address.find_or_create_by_spec(self.email_address).canonicalize
    addresses = Address.find_by_sql([<<-"SQL", self.id, account_address.id, limit])
      SELECT (CASE WHEN canonical_address_id THEN canonical_address_id ELSE addresses.id END) AS id, COUNT(*) AS count FROM addresses
      JOIN message_associations ON address_id=addresses.id
      JOIN messages ON message_id=messages.id
      WHERE messages.account_id = ?
      AND domain_name IS NOT NULL
      AND (canonical_address_id IS NULL OR canonical_address_id != ?)
      GROUP BY id
      ORDER BY COUNT(*) DESC
      LIMIT ?
    SQL
    Address.find(addresses.map(&:id))
  end
end

class Token < ActiveRecord::Base; end
