class Profile < ApplicationRecord
  belongs_to :user
  has_many :usps_confirmation_codes

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope(:active, -> { where(active: true) })
  scope(:verified, -> { where.not(verified_at: nil) })

  enum deactivation_reason: {
    password_reset: 1,
    encryption_error: 2,
    verification_pending: 3,
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

  def decrypt_pii(user_access_key)
    Pii::Attributes.new_from_encrypted(encrypted_pii, user_access_key)
  end

  def recover_pii(personal_key)
    rc_user_access_key = UserAccessKey.new(
      password: personal_key,
      salt: user.recovery_salt,
      cost: user.recovery_cost
    )
    EncryptedKeyMaker.new.make(rc_user_access_key)
    Pii::Attributes.new_from_encrypted(encrypted_pii_recovery, rc_user_access_key)
  end

  def encrypt_pii(user_access_key, pii)
    ssn = pii.ssn
    self.ssn_signature = Pii::Fingerprinter.fingerprint(ssn) if ssn
    self.encrypted_pii = pii.encrypted(user_access_key)
    encrypt_recovery_pii(pii)
  end

  def encrypt_recovery_pii(pii)
    personal_key, rc_user_access_key = generate_personal_key
    self.encrypted_pii_recovery = pii.encrypted(rc_user_access_key)
    @personal_key = personal_key
  end

  private

  def personal_key_generator
    @_personal_key_generator ||= PersonalKeyGenerator.new(user)
  end

  def generate_personal_key
    personal_key = personal_key_generator.create
    [personal_key, personal_key_generator.user_access_key]
  end
end
