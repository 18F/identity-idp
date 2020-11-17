class AddEmailLanguageToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :email_language, :string, null: true, limit: 10
  end
end
