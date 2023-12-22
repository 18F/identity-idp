class GpoConfirmation < ApplicationRecord
  self.table_name = 'usps_confirmations'

  validates :entry, presence: true
  validates :otp, :address1, :city, :state, :zipcode, presence: true
  validate :zipcode_is_valid

  ZIP_REGEX = /\A\d{5}\s*-?\s*(\d{4})?\Z/

  def method_missing(method, *args)
    # Forward through attribute reads to entry
    entry[method] if args.count == 0
  end

  def respond_to_missing?(method)
    method = method.to_s
    !(method.endswith('?') || method.endswith('='))
  end

  # Store the pii as encrypted json
  def entry=(entry_hash)
    self[:entry] = encryptor.encrypt(entry_hash.to_json)
    @entry = nil
  end

  # Read the pii as a decrypted hash
  def entry
    @entry ||= JSON.parse(encryptor.decrypt(self[:entry]), symbolize_names: true)
  end

  private

  def encryptor
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new
  end

  def zipcode_is_valid
    if !ZIP_REGEX.match(zipcode&.strip)
      errors.add(:zipcode, :invalid)
    end
  end
end
