class AddAgreementStepsToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :agreement_view_at, :datetime
      add_column :doc_auth_logs, :agreement_view_count, :integer, default: 0
    end
  end
end
