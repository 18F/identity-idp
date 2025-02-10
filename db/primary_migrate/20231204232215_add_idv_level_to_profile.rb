class AddIdvLevelToProfile < ActiveRecord::Migration[7.1]
  def change
    add_column :profiles, :idv_level, :integer
  end
end
