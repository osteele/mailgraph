require 'active_record'
require 'sqlite3'
require 'logger'

class Schema < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.string :email_address
      t.integer :message_count
    end

    add_index :accounts, :email_address, :unique => true

    create_table :addresses do |t|
      t.string :display_name
      t.string :spec
      t.string :domain_name
      t.integer :canonical_address_id, :references => [:addresses, :id]
    end

    add_index :addresses, :spec
    add_index :addresses, :domain_name
    add_index :addresses, [:display_name, :spec]

    create_table :messages do |t|
      t.integer :account_id, :null => false, :default => 1, :references => [:accounts, :id]
      t.integer :uid, :null => false
      t.string :subject
      t.datetime :date
      t.string :gm_message_id  # X-GM-MSGID
      t.string :gm_thread_id   # X-GM-THRID
    end

    add_index :messages, [:account_id, :uid], :unique => true
    add_index :messages, :date

    create_table :message_associations, :id => false do |t|
      t.integer :message_id, :null => false, :references => [:messages, :id]
      t.integer :address_id, :null => false, :references => [:addresses, :id]
      t.string :field, :limit => 4, :null => false # ("from", "to", "cc", "bcc")
    end

    add_index :message_associations, :message_id
    add_index :message_associations, :address_id
    add_index :message_associations, [:message_id, :field]

    create_table :tokens do |t|
      t.string :user, :null => false
      t.string :access_token, :null => false
      t.string :refresh_token, :null => false
      t.datetime :expires_at, :null => false
    end

    add_index :tokens, :user, :unique => true
  end
end

class Migration < ActiveRecord::Migration
  def change
  end
end

if __FILE__ == $0
  ActiveRecord::Base.logger = Logger.new('debug.log')
  ActiveRecord::Base.configurations = YAML::load(IO.read('database.yml'))
  environment = 'development'
  ActiveRecord::Base.establish_connection(environment)
  Schema.new.change unless File.exists?('db/data.sqlite3') and ActiveRecord::Base.configurations[environment]['adapter'] == 'sqlite3'
  Migration.new.change
end
