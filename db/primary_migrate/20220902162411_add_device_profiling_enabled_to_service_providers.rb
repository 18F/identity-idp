class AddDeviceProfilingEnabledToServiceProviders < ActiveRecord::Migration[7.0]
  def up
    add_column :service_providers, :device_profiling_enabled, :boolean
    change_column_default :service_providers, :device_profiling_enabled, false
  end

  def down
    remove_column :service_providers, :device_profiling_enabled
  end
end
