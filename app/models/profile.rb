class Profile < ApplicationRecord
  self.ignored_columns = %w[phone_confirmed]

  belongs_to :user
  has_many :usps_confirmation_codes, dependent: :destroy

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope(:active, -> { where(active: true) })
  scope(:verified, -> { where.not(verified_at: nil) })

  enum deactivation_reason: {
    password_reset: 1,
    encryption_error: 2,
    verification_pending: 3,
    verification_cancelled: 4,
    in_person_pending: 5,
  }

  attr_reader :personal_key

  # rubocop:disable Rails/SkipsModelValidations
  def activate
    now = Time.zone.now
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: now, deactivation_reason: nil, verified_at: now)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  def decrypt_pii(password)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    decrypted_json = encryptor.decrypt(encrypted_pii, user_uuid: user.uuid)
    Pii::Attributes.new_from_json(decrypted_json)
  end

  def recover_pii(personal_key)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)
    decrypted_recovery_json = encryptor.decrypt(encrypted_pii_recovery, user_uuid: user.uuid)
    Pii::Attributes.new_from_json(decrypted_recovery_json)
  end

  def encrypt_pii(pii, password)
    ssn = pii.ssn
    self.ssn_signature = Pii::Fingerprinter.fingerprint(ssn) if ssn
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    self.encrypted_pii = encryptor.encrypt(pii.to_json, user_uuid: user.uuid)
    encrypt_recovery_pii(pii)
  end

  def encrypt_recovery_pii(pii)
    personal_key = personal_key_generator.create
    encryptor = Encryption::Encryptors::PiiEncryptor.new(
      personal_key_generator.normalize(personal_key),
    )
    self.encrypted_pii_recovery = encryptor.encrypt(pii.to_json, user_uuid: user.uuid)
    @personal_key = personal_key
  end

  private

  def personal_key_generator
    @_personal_key_generator ||= PersonalKeyGenerator.new(user)
  end
end
