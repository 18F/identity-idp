class FixPhoneConfigurationIndex < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def up
    add_index(
      :phone_configurations,
      %i[user_id made_default_at created_at],
      algorithm: :concurrently,
      name: 'index_phone_configurations_on_made_default_at',
    )
    remove_index :phone_configurations, %i[made_default_at created_at]
  end

  def down
    remove_index :phone_configurations, %i[user_id made_default_at created_at]
    add_index(
      :phone_configurations,
      %i[made_default_at created_at],
      algorithm: :concurrently,
    )
  end
end
