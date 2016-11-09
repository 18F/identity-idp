class LimitSessions < ActiveRecord::Migration
  def change
    add_column :users, :unique_session_id, :string
  end
end
