class UpdateUserProofingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :user_proofing_events,
               :service_provider_ids_sent,
               :bigint,
               null: false,
               default: [],
               array: true,
               comment: 'sensitive=false'

    change_column_null(:user_proofing_events, :encrypted_events, true)
  end
end
