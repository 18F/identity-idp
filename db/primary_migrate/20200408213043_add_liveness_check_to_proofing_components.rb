class AddLivenessCheckToProofingComponents < ActiveRecord::Migration[5.2]
  def change
    add_column :proofing_components, :liveness_check, :string
  end
end
