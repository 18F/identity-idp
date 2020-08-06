class BackfillAddAcuantResultToProofingCosts < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    ProofingCost.unscoped.in_batches do |relation|
      relation.update_all acuant_result_count: 0
      sleep(0.01)
    end
  end
end
