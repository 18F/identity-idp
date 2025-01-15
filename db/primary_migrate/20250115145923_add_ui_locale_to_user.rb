class AddUiLocaleToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :locale, :string, comment: "sensitive=false"
  end
end
