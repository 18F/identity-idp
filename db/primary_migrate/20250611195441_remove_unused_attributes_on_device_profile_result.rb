class RemoveUnusedAttributesOnDeviceProfileResult < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :device_profiling_results, :reason
      remove_column :device_profiling_results, :success
    end
  end
end
