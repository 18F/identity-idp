class DropSessionsTable < ActiveRecord::Migration
  def change
    drop_table :sessions
  end
end
