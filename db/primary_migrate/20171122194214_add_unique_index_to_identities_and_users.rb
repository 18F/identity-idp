class AddUniqueIndexToIdentitiesAndUsers < ActiveRecord::Migration[5.1]
  def change
    remove_index :identities, %i[user_id service_provider]
    add_index :identities, %i[user_id service_provider], unique: true
  end
end
