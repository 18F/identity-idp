class AddNotesToDeviceProfilingResult < ActiveRecord::Migration[8.0]
  def up
    add_column :device_profiling_results, :notes, :string, comment: 'sensitive=false'
  end

  def down
    remove_column :device_profiling_results, :notes
  end
end
