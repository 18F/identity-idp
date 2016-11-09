class UpdateSessionsForConcurrency < ActiveRecord::Migration
  def change
    remove_column :sessions, :data
    add_reference :sessions, :identity, index: true, foreign_key: true, null: false
  end
end
