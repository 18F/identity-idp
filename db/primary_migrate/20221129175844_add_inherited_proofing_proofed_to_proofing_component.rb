class AddInheritedProofingProofedToProofingComponent < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :proofing_components, :inherited_proofing_proofed, :boolean, default: false, null: false, comment: "When the user is proofed via inherited proofing"
  end
end
