class DropDeviceProfilingEnabledFromServiceProviders < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :service_providers, :device_profiling_enabled, :boolean, default: false }
  end
end
