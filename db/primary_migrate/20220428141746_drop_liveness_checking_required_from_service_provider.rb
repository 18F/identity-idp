class DropLivenessCheckingRequiredFromServiceProvider < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :service_providers, :liveness_checking_required, :boolean }
  end
end
