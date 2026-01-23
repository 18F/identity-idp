class LimitWebAuthnConfigurationsNameLength < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL
        UPDATE webauthn_configurations
        SET name = LEFT(name, 80)
        WHERE LENGTH(name) > 80;
      SQL

      change_column :webauthn_configurations, :name, :string, limit: 80
    end
  end

  def down
    safety_assured do
      change_column :webauthn_configurations, :name, :string
    end
  end
end
