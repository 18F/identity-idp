class AddIrsAttemptsApiEnabledToServiceProvider < ActiveRecord::Migration[6.1]
  def change
    add_column :service_providers, :irs_attempts_api_enabled, :boolean
  end
end
