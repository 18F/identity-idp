class AddHelpTextToServiceProviders < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :help_text, :jsonb
    change_column_default :service_providers, :help_text, sign_in: {}, sign_up: {}, forgot_password: {}
  end

  def down
    remove_column :service_providers, :help_text
  end
end
