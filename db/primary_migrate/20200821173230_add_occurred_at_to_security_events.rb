class AddOccurredAtToSecurityEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :security_events, :occurred_at, :timestamp
  end
end
