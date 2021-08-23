class RemoveUserIdIndexFromEvents < ActiveRecord::Migration[6.1]
  def change
    remove_index :events, name: "index_events_on_user_id"
  end
end
