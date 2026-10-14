class AddBiometricSharingConsentAtToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :biometric_sharing_consent_at, :datetime,
               comment: 'sensitive=false'
  end
end
