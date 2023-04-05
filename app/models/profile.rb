class Profile < ApplicationRecord
  self.ignored_columns = %w[phone_confirmed]

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
    gpo_verification_pending: 3,
    verification_cancelled: 4,
    in_person_verification_pending: 5,
  }

  attr_reader :personal_key

  def fraud_review_pending?
    !!(fraud_review_pending || fraud_review_pending_at)
  end

  def fraud_rejection?
    !!(fraud_rejection || fraud_rejection_at)
  end

  # rubocop:disable Rails/SkipsModelValidations
  def activate
    return if fraud_review_pending? || fraud_rejection?
    now = Time.zone.now
    is_reproof = Profile.find_by(user_id: user_id, active: true)
    transaction do
      Profile.where(user_id: user_id).update_all(active: false)
      update!(
        active: true,
        activated_at: now,
        deactivation_reason: nil,
        fraud_review_pending: false,
        fraud_rejection: false,
        verified_at: now,
      )
    end
    send_push_notifications if is_reproof
  end
  # rubocop:enable Rails/SkipsModelValidations

  def activate_after_passing_review
    update!(fraud_review_pending: false, fraud_rejection: false, fraud_review_pending_at: nil, fraud_rejection_at: nil)
    track_fraud_review_adjudication(decision: 'pass')
    activate
  end

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  def deactivate_for_fraud_review
    update!(active: false, fraud_review_pending: true, fraud_rejection: false, fraud_review_pending_at: Time.zone.now, fraud_rejection_at: nil)
  end

  def reject_for_fraud(notify_user:)
    update!(active: false, fraud_review_pending: false, fraud_rejection: true, fraud_review_pending_at: nil, fraud_rejection_at: Time.zone.now)
    track_fraud_review_adjudication(
      decision: notify_user ? 'manual_reject' : 'automatic_reject',
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

  def irs_attempts_api_tracker
    @irs_attempts_api_tracker ||= IrsAttemptsApi::Tracker.new(
      session_id: nil,
      request: nil,
      user: user,
      sp: initiating_service_provider,
      cookie_device_uuid: nil,
      sp_request_uri: nil,
      enabled_for_session: initiating_service_provider&.irs_attempts_api_enabled?,
      analytics: Analytics.new(
        user: user,
        request: nil,
        sp: initiating_service_provider&.issuer,
        session: {},
        ahoy: nil,
      ),
    )
  end

  private

  def track_fraud_review_adjudication(decision:)
    if IdentityConfig.store.irs_attempt_api_track_idv_fraud_review
      fraud_review_request = user.fraud_review_requests.last
      irs_attempts_api_tracker.fraud_review_adjudicated(
        decision: decision,
        cached_irs_session_id: fraud_review_request&.irs_session_id,
        cached_login_session_id: fraud_review_request&.login_session_id,
      )
    end
  end

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
