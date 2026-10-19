class CreateUserConsentSts < ActiveRecord::Migration[8.1]
  def change
    create_table :user_consent_sts,
                 comment: 'Records of user consent for STS token exchange flows' do |t|
      t.references :user, null: false, foreign_key: true, comment: 'sensitive=false'
      t.string :target_app, null: false,
                            comment: 'Issuer of the broker SP the user consented to sensitive=false'
      t.datetime :created_at, null: false, comment: 'sensitive=false'
      t.datetime :updated_at, null: false, comment: 'sensitive=false'

      t.index [:user_id, :target_app], unique: true,
                                       name: 'index_user_consent_sts_on_user_id_and_target_app'
    end
  end
end
