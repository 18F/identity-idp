class AddRecoverySalt < ActiveRecord::Migration
  class User < ActiveRecord::Base
    def postpone_email_change?
      false
    end
  end

  def change
    add_column :users, :recovery_salt, :string
  end
end
