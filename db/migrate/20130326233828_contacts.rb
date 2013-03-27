class Contacts < ActiveRecord::Migration
  def up
    create_table :contacts do |t|
      t.references :account, :null => false
      t.string :uid, :null => false
      t.string :name
    end

    add_index :contacts, [:account_id, :uid], :unique => true

    create_table :addresses_contacts, :id => false do |t|
      t.references :contact, :null => false
      t.references :address, :null => false
    end

    add_index :addresses_contacts, :contact_id
    add_index :addresses_contacts, :address_id
  end

  def down
    drop_table :contacts
    drop_table :addresses_contacts
  end
end
