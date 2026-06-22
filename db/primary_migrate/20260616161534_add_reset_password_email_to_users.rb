class AddResetPasswordEmailToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :reset_password_email, :string, limit: 255, comment: 'sensitive=false'
  end
end
