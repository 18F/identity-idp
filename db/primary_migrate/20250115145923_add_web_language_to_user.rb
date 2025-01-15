class AddWebLanguageToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :web_language, :string, comment: "sensitive=false"
  end
end
