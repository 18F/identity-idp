class AddTargetToThrottles < ActiveRecord::Migration[6.1]
  def change
    change_column_null :throttles, :user_id, true

    add_column :throttles, :target, :string, null: true
  end
end
