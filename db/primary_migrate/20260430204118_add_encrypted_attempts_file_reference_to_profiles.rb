class AddEncryptedAttemptsFileReferenceToProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :profiles, :encrypted_attempts_file_reference, :string, comment: 'sensitive=false'
  end
end
