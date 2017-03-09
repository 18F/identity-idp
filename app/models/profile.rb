class Profile < ActiveRecord::Base
  belongs_to :user

  validates :active, uniqueness: { scope: :user_id, if: :active? }
  validates :ssn_signature, uniqueness: { scope: :active, if: :active? }

  scope :active, -> { where(active: true) }
  scope :verified, -> { where.not(verified_at: nil) }

  enum deactivation_reason: {
    password_reset: 1,
    encryption_error: 2,
    verification_pending: 3,
  }

  attr_reader :recovery_code

  def activate
    transaction do
      Profile.where('user_id=?', user_id).update_all(active: false)
      update!(active: true, activated_at: Time.zone.now)
    end
  end

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  def decrypt_pii(user_access_key)
    Pii::Attributes.new_from_encrypted(encrypted_pii, user_access_key)
  end

  def recover_pii(recovery_code)
    rc_user_access_key = UserAccessKey.new(
      password: recovery_code,
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
    recovery_code, rc_user_access_key = generate_recovery_code
    self.encrypted_pii_recovery = pii.encrypted(rc_user_access_key)
    @recovery_code = recovery_code
  end

  private

  def recovery_code_generator
    @_recovery_code_generator ||= RecoveryCodeGenerator.new(user)
  end

  def generate_recovery_code
    recovery_code = recovery_code_generator.create
    [recovery_code, recovery_code_generator.user_access_key]
  end
end
