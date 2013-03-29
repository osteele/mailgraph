# include DBViews

require_relative './environments'

def view(name, sql)
  puts "Creating database view #{name}"
  connection = ActiveRecord::Base.connection
  case connection.class.name[/([^:]+)Adapter$/, 1]
  when 'Mysql', 'PostgreSQL'
    connection.execute "CREATE OR REPLACE VIEW #{name} AS #{sql}"
  when 'SQLite3'
    connection.execute "DROP VIEW IF EXISTS #{name}"
    connection.execute "CREATE VIEW #{name} AS #{sql}"
  else
    raise "Unimplemented connection class #{connection.class}"
  end
end

view :computed_addresses_contacts, <<-SQL
  SELECT account_id, addresses.id AS address_id, contact_id, addresses.spec, addresses.display_name
  FROM addresses
  JOIN addresses AS contact_address ON addresses.spec=contact_address.spec
  JOIN addresses_contacts ON addresses_contacts.address_id=contact_address.id
  JOIN contacts ON addresses_contacts.contact_id=contacts.id
  JOIN accounts ON contacts.account_id=accounts.id
SQL

view :contacts_messages_view, <<-SQL
  CREATE VIEW contacts_messages_view AS SELECT contacts.*, message_id, field
  FROM contacts
  JOIN computed_addresses_contacts ON computed_addresses_contacts.contact_id=contacts.id
  JOIN message_associations ON computed_addresses_contacts.address_id=message_associations.address_id
end
