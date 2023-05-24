class Profile < ApplicationRecord
  belongs_to :user
  # rubocop:disable Rails/InverseOf
  belongs_to :initiating_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'initiating_service_provider_issuer',
             primary_key: 'issuer',
             optional: true
  # rubocop:enable Rails/InverseOf
  has_many :gpo_confirmation_codes, dependent: :destroy
  has_one :in_person_enrollment, dependent: :destroy

  validates :active, uniqueness: { scope: :user_id, if: :active? }

  scope(:active, -> { where(active: true) })
  scope(:verified, -> { where.not(verified_at: nil) })

  enum deactivation_reason: {
    password_reset: 1,
    encryption_error: 2,
    gpo_verification_pending_NO_LONGER_USED: 3, # deprecated
    verification_cancelled: 4,
    in_person_verification_pending: 5,
  }

  attr_reader :personal_key

  def fraud_review_pending?
    fraud_review_pending_at.present?
  end

  def fraud_rejection?
    fraud_rejection_at.present?
  end

  def gpo_verification_pending?
    gpo_verification_pending_at.present?
  end

  def pending_reasons
    [
      *(:gpo_verification_pending if gpo_verification_pending?),
      *(:fraud_check_pending if has_fraud_deactivation_reason?),
      *(:in_person_verification_pending if in_person_verification_pending?),
    ]
  end

  # rubocop:disable Rails/SkipsModelValidations
  def activate
    confirm_that_profile_can_be_activated!

    now = Time.zone.now
    is_reproof = Profile.find_by(user_id: user_id, active: true)
    transaction do
      Profile.where(user_id: user_id).update_all(active: false)
      update!(
        active: true,
        activated_at: now,
        verified_at: now,
      )
    end
    send_push_notifications if is_reproof
  end
  # rubocop:enable Rails/SkipsModelValidations

  def confirm_that_profile_can_be_activated!
    if pending_reasons.any?
      raise "Attempting to activate profile with pending reasons: #{pending_reasons.join(',')}"
    elsif deactivation_reason.present?
      raise "Attempting to activate profile with deactivation reason: #{deactivation_reason}"
    end
  end

  def remove_gpo_deactivation_reason
    update!(gpo_verification_pending_at: nil)
    update!(deactivation_reason: nil) if gpo_verification_pending_NO_LONGER_USED?
  end

  def activate_after_passing_review
    update!(
      fraud_review_pending_at: nil,
      fraud_rejection_at: nil,
    )
    activate
  end

  def activate_after_passing_in_person
    update!(
      deactivation_reason: nil,
    )
    activate
  end

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  def has_deactivation_reason?
    deactivation_reason.present? || has_fraud_deactivation_reason? || gpo_verification_pending?
  end

  def has_fraud_deactivation_reason?
    fraud_review_pending? || fraud_rejection?
  end

  def deactivate_for_gpo_verification
    update!(active: false, gpo_verification_pending_at: Time.zone.now)
  end

  def deactivate_for_fraud_review
    update!(
      active: false,
      fraud_review_pending_at: Time.zone.now,
      fraud_rejection_at: nil,
    )
  end

  def reject_for_fraud(notify_user:)
    update!(
      active: false,
      fraud_review_pending_at: nil,
      fraud_rejection_at: Time.zone.now,
    )
    UserAlerts::AlertUserAboutAccountRejected.call(user) if notify_user
  end

  def decrypt_pii(password)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    decrypted_json = encryptor.decrypt(encrypted_pii, user_uuid: user.uuid)
    Pii::Attributes.new_from_json(decrypted_json)
  end

  # @return [Pii::Attributes]
  def recover_pii(personal_key)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)
    decrypted_recovery_json = encryptor.decrypt(encrypted_pii_recovery, user_uuid: user.uuid)
    return nil if JSON.parse(decrypted_recovery_json).nil?
    Pii::Attributes.new_from_json(decrypted_recovery_json)
  end

  # @param [Pii::Attributes] pii
  def encrypt_pii(pii, password)
    encrypt_ssn_fingerprint(pii)
    encrypt_compound_pii_fingerprint(pii)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    self.encrypted_pii = encryptor.encrypt(pii.to_json, user_uuid: user.uuid)
    encrypt_recovery_pii(pii)
  end

  # @param [Pii::Attributes] pii
  def encrypt_recovery_pii(pii)
    personal_key = personal_key_generator.create
    encryptor = Encryption::Encryptors::PiiEncryptor.new(
      personal_key_generator.normalize(personal_key),
    )
    self.encrypted_pii_recovery = encryptor.encrypt(pii.to_json, user_uuid: user.uuid)
    @personal_key = personal_key
  end

  # @param [Pii::Attributes] pii
  def self.build_compound_pii(pii)
    values = [
      pii.first_name,
      pii.last_name,
      pii.zipcode,
      pii.dob && DateParser.parse_legacy(pii[:dob]).year,
    ]

    return unless values.all?(&:present?)
    values.join(':')
  end

  def includes_phone_check?
    return false if proofing_components.blank?
    proofing_components['address_check'] == 'lexis_nexis_address'
  end

  def has_proofed_before?
    Profile.where(user_id: user_id).where.not(activated_at: nil).where.not(id: self.id).exists?
  end

  private

  def personal_key_generator
    @personal_key_generator ||= PersonalKeyGenerator.new(user)
  end

  def encrypt_ssn_fingerprint(pii)
    ssn = pii.ssn
    self.ssn_signature = Pii::Fingerprinter.fingerprint(ssn) if ssn
  end

  def encrypt_compound_pii_fingerprint(pii)
    compound_pii = self.class.build_compound_pii(pii)

    if compound_pii
      self.name_zip_birth_year_signature = Pii::Fingerprinter.fingerprint(compound_pii)
    end
  end

  def send_push_notifications
    event = PushNotification::ReproofCompletedEvent.new(user: user)
    PushNotification::HttpPush.deliver(event)
  end
end
