class GpoConfirmation < ApplicationRecord
  self.table_name = 'usps_confirmations'

  validates :entry, presence: true
  validates :otp, :address1, :city, :state, :zipcode, presence: true
  validate :zipcode_is_valid

  ZIP_REGEX = /^(\d{5})[-+]?(\d+)?$/

  def method_missing(method, *args)
    # Forward through attribute reads to entry
    entry[method] if args.count == 0
  end

  def respond_to_missing?(method, ...)
    method = method.to_s
    !(method.endswith('?') || method.endswith('='))
  end

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

  def zipcode_is_valid
    if self.class.normalize_zipcode(zipcode).nil?
      errors.add(:zipcode, :invalid)
    end
  end
end
