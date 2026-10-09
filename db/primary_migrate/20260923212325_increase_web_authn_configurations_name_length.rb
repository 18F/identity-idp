class IncreaseWebAuthnConfigurationsNameLength < ActiveRecord::Migration[8.1]
  def up
     safety_assured do
       change_column :webauthn_configurations, :name, :string, limit: 180
     end
   end

   def down
     safety_assured do
       change_column :webauthn_configurations, :name, :string, limit: 80
     end
   end
end
