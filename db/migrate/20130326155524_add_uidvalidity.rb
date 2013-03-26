class AddUidvalidity < ActiveRecord::Migration
  def up
    create_table :mailboxes do |t|
      t.references :account, :null => false
      t.string :name, :null => false
      t.integer :uidvalidity
    end

    change_table :messages do |t|
      t.references :mailbox
    end
  end

  def down
    remove_column :messages, :mailbox_id
    drop_table :mailboxes
  end
end
