class AddHelpTextToServiceProviders < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :help_text, :jsonb
    change_column_default :service_providers, :help_text, sign_in: {}, sign_up: {}, forgot_password: {}
    ServiceProvider.find_each do |sp|
      sp.help_text = { sign_in: {}, sign_up: {}, forgot_password: {} }
      sp.save!
    end
  end

  def down
    remove_column :service_providers, :help_text
  end
end
