class AddUniqueIndexToChannelGupshup < ActiveRecord::Migration[7.0]
  def change
    add_index :channel_gupshup, [:phone_number, :account_id], unique: true
  end
end
