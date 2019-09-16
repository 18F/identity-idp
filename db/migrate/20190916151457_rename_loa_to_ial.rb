class RenameLoaToIal < ActiveRecord::Migration[5.1]
  def change
    safety_assured { rename_column :service_provider_requests, :loa, :ial }
  end
end
