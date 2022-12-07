class GpoConfirmation < ApplicationRecord
  self.table_name = 'usps_confirmations'

  # Store the pii as encrypted json
  def entry=(entry_hash)
    self[:entry] = encryptor.encrypt(entry_hash.to_json)
  end

  # Read the pii as a decrypted hash
  def entry
    JSON.parse(encryptor.decrypt(self[:entry]), symbolize_names: true)
  end

  private

  def encryptor
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new
  end
end

# == Schema Information
#
# Table name: usps_confirmations
#
#  id         :integer          not null, primary key
#  entry      :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
