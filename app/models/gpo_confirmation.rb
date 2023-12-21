class GpoConfirmation < ApplicationRecord
  self.table_name = 'usps_confirmations'

  validates :entry, presence: true
  validate :entry_has_all_required_fields
  validate :entry_has_valid_zipcode

  ZIP_REGEX = /\A\d{5}\s*-?\s*(\d{4})?\Z/
  REQUIRED_ENTRY_FIELDS = %i[otp address1 city state zipcode ]

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

  def entry_has_all_required_fields
    REQUIRED_ENTRY_FIELDS.each do |field|
      if entry[field].blank?
        errors.add(:entry, :invalid)
    end
    end
  end

  def entry_has_valid_zipcode
    if !ZIP_REGEX.match(entry[:zipcode]&.strip)
      errors.add(:entry, :invalid)
    end
  end
end
