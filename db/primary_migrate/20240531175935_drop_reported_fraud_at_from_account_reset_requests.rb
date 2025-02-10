class DropReportedFraudAtFromAccountResetRequests < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :account_reset_requests, :reported_fraud_at, :datetime, precision: nil
    end
  end
end
