class GpoConfirmation < ApplicationRecord
  self.table_name = 'usps_confirmations'

  ENTRY_ATTRIBUTES = %i[otp address1 city state zipcode]
  ENTRY_ATTRIBUTES.each do |attr|
    define_method("entry_#{attr}".to_sym) do
      entry[attr]
    end
  end

  validates :entry, presence: true
  validates :entry_otp, :entry_address1, :entry_city, :entry_state, :entry_zipcode, presence: true
  validate :entry_zipcode_is_valid

  ZIP_REGEX = /^(\d{5})[-+]?(\d+)?$/

  # Store the pii as encrypted json
  def entry=(entry_hash)
    @entry = nil
    self[:entry] = encryptor.encrypt(
      entry_hash.
        dup.
        tap do |h|
          h[:zipcode] = self.class.normalize_zipcode(h[:zipcode]) if h[:zipcode].present?
        end.
        to_json,
    )
  end

  # Read the pii as a decrypted hash
  def entry
    @entry ||= JSON.parse(encryptor.decrypt(self[:entry]), symbolize_names: true)
  end

  def self.normalize_zipcode(zipcode)
    _, zip, plus4 = ZIP_REGEX.match(zipcode&.gsub(/\s/, '')).to_a
    if plus4&.length == 4
      "#{zip}-#{plus4}"
    else
      zip
    end
  end

  private

  def encryptor
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new
  end

  def entry_zipcode_should_be_rejected_because_we_are_testing?
    # We reserve a certain zipcode to be used to test this value in lower environments.
    entry_zipcode.present? &&
      entry_zipcode == IdentityConfig.store.invalid_gpo_confirmation_zipcode
  end

  def entry_zipcode_is_valid
    normalized = self.class.normalize_zipcode(entry_zipcode)

    if normalized.nil? || entry_zipcode_should_be_rejected_because_we_are_testing?
      errors.add(:entry_zipcode, :invalid)
    end
  end
end
