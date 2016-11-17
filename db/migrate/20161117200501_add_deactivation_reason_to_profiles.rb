class AddDeactivationReasonToProfiles < ActiveRecord::Migration
  def change
    add_column :profiles, :deactivation_reason, :integer, limit: 4, null: false, default: 0
  end
end
