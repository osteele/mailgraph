class Address < ActiveRecord::Base
  has_and_belongs_to_many :contacts

  def self.from_imap_address(address)
    self.where(:display_name => address.name, :spec => "#{address.mailbox}@#{address.host}", :domain_name => address.host).first_or_create
  end

  def self.from_string(address)
    name, domain_name = address.split(/@/, 2)
    self.where(:display_name => address, :spec => address, :domain_name => domain_name).first_or_create
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

class Contact < ActiveRecord::Base
  has_and_belongs_to_many :addresses
  belongs_to :primary_address, :class_name => Address

  def self.for_address_spec(address_spec, account)
    contacts = self.find_by_sql([<<-"SQL", account.id, address_spec])
      SELECT * FROM contacts
      JOIN computed_addresses_contacts ON computed_addresses_contacts.contact_id=contacts.id
      WHERE computed_addresses_contacts.account_id=? AND computed_addresses_contacts.spec=?
      GROUP BY contacts.id
    SQL
    throw "No contact for #{address_spec} in account #{account.email_address}" unless contacts.any?
    throw "Too many contacts for #{address_spec}" if contacts.length > 1
    return contacts.first
  end
end

class Mailbox < ActiveRecord::Base
  belongs_to :account
  has_many :messages
end

class MessageAssociation < ActiveRecord::Base
  belongs_to :message
  belongs_to :address
end

class Message < ActiveRecord::Base
  belongs_to :mailbox
  has_many :message_associations
end

class Account < ActiveRecord::Base
  has_many :mailboxes
  has_many :messages
end

class Token < ActiveRecord::Base; end
