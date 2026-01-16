class SetNameLengthInPivCacConfiguration < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      change_column :piv_cac_configurations, :name, :string, limit: 80
    end
  end

  def down
    safety_assured do
      change_column :piv_cac_configurations, :name, :string
    end
  end
end
