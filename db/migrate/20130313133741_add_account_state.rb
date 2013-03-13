class AddAccountState < ActiveRecord::Migration
  def up
    add_column :accounts, :admin, :boolean, :default => false
    add_column :accounts, :active, :boolean, :default => false
  end

  def down
    remove_column :accounts, :admin
    remove_column :accounts, :active
  end
end
