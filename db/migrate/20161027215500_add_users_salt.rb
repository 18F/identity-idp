class AddUsersSalt < ActiveRecord::Migration
  class User < ActiveRecord::Base
    def postpone_email_change?
      false
    end
  end

  def change
    add_column :users, :password_salt, :string
  end
end
