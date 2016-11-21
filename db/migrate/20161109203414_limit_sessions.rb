class LimitSessions < ActiveRecord::Migration
  class User < ActiveRecord::Base
    def postpone_email_change?
      false
    end
  end

  def change
    add_column :users, :unique_session_id, :string
  end
end
