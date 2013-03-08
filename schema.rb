require 'active_record'
require 'sqlite3'
require 'logger'

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

    add_index :messages, :uid, :unique => true
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

class Migration < ActiveRecord::Migration
  def change
    create_table :tokens do |t|
      t.string :user
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at
    end

    add_index :tokens, :user
  end
end

if __FILE__ == $0
  ActiveRecord::Base.logger = Logger.new('debug.log')
  ActiveRecord::Base.configurations = YAML::load(IO.read('database.yml'))
  ActiveRecord::Base.establish_connection('development')
  Schema.new.change unless File.exists?('db/data.sqlite3')
  Migration.new.change
end
