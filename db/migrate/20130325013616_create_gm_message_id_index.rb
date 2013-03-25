class CreateGmMessageIdIndex < ActiveRecord::Migration
  def up
    remove_index :messages, [:account_id, :gm_message_id]
    add_index :messages, [:account_id, :uid]
  end

  def down
    add_index :messages, [:account_id, :uid]
    remove_index :messages, [:account_id, :gm_message_id]
  end
end
