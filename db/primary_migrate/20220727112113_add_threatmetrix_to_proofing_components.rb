class AddThreatmetrixToProofingComponents < ActiveRecord::Migration[6.1]
  def change
    add_column :proofing_components, :device_fingerprinting_vendor, :string
    add_column :proofing_components, :threatmetrix, :boolean
    add_column :proofing_components, :threatmetrix_review_status, :string
    add_column :proofing_components, :threatmetrix_risk_rating, :string
    add_column :proofing_components, :threatmetrix_policy_score, :string
  end
end
