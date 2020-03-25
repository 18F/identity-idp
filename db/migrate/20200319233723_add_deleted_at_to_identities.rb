class AddDeletedAtToIdentities < ActiveRecord::Migration[5.1]
  def change
    add_column :identities, :deleted_at, :datetime, null: true
  end
end
