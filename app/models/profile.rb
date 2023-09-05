class Profile < ApplicationRecord
  include AASM

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

  has_one :establishing_in_person_enrollment,
          -> { where(status: :establishing).order(created_at: :desc) },
          class_name: 'InPersonEnrollment', foreign_key: :profile_id, inverse_of: :profile,
          dependent: :destroy

  enum deactivation_reason: {
    password_reset: 1,
    encryption_error: 2,
    gpo_verification_pending_NO_LONGER_USED: 3, # deprecated
    verification_cancelled: 4,
    in_person_verification_pending_NO_LONGER_USED: 5, # deprecated
  }

  enum fraud_pending_reason: {
    threatmetrix_review: 1,
    threatmetrix_reject: 2,
  }

  attr_reader :personal_key

  # rubocop:disable Metrics/BlockLength
  aasm :fraud, column: :fraud_state, timestamps: true do
    state :fraud_none, initial: true
    state :fraud_review_pending, :fraud_rejection, :fraud_passed
    event :fraud_review do
      transitions(
        from: [
          :fraud_none,
          # TODO: the following 2 states are actually newly discovered states:
          # this is really the state right after profile creation
          :fraud_review_pending,
          # `ThreatMetrix says "reject"`, see gpo_otp_verification_step_spec.rb
          :fraud_rejection,
        ],
        to: :fraud_review_pending,
      )
    end
    event :fraud_reject do
      transitions from: :fraud_review_pending, to: :fraud_rejection
    end

    event :fraud_reset do
      transitions(
        from: [
          :fraud_review_pending,
          :fraud_rejection,
        ],
        to: :fraud_none,
      )
    end

    event :fraud_pass do
      transitions(
        from: [
          :fraud_none, # see GpoVerifyForm#activate_profile
          :fraud_review_pending,
          :fraud_rejection,
        ],
        to: :fraud_passed,
      )
    end
  end
  # rubocop:enable Metrics/BlockLength

  # Class methods
  def self.active
    where(active: true)
  end

  def self.verified
    where.not(verified_at: nil)
  end

  def self.fraud_rejection
    where.not(fraud_rejection_at: nil)
  end

  def self.fraud_review_pending
    where.not(fraud_review_pending_at: nil)
  end

  def self.gpo_verification_pending
    where.not(gpo_verification_pending_at: nil)
  end

  def self.in_person_verification_pending
    where.not(in_person_verification_pending_at: nil)
  end

  # Instance methods
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
  def activate(reason_deactivated: nil)
    confirm_that_profile_can_be_activated!

    now = Time.zone.now
    is_reproof = Profile.find_by(user_id: user_id, active: true)

    attrs = {
      active: true,
      activated_at: now,
    }

    attrs[:verified_at] = now unless (reason_deactivated == :password_reset || verified_at)

    transaction do
      Profile.where(user_id: user_id).update_all(active: false)
      update!(attrs)
    end
    send_push_notifications if is_reproof
  end
  # rubocop:enable Rails/SkipsModelValidations

  def reason_not_to_activate
    if pending_reasons.any?
      "Attempting to activate profile with pending reasons: #{pending_reasons.join(',')}"
    elsif deactivation_reason.present?
      "Attempting to activate profile with deactivation reason: #{deactivation_reason}"
    end
  end

  def remove_gpo_deactivation_reason
    update!(gpo_verification_pending_at: nil)
    update!(deactivation_reason: nil) if gpo_verification_pending_NO_LONGER_USED?
  end

  def activate_after_passing_review
    transaction do
      fraud_pass
      update!(
        fraud_pending_reason: nil,
      )
      activate
    end

    track_fraud_review_adjudication(decision: 'pass') if active?
  end

  def activate_after_fraud_review_unnecessary
    transaction do
      fraud_pass
      update!(
        fraud_pending_reason: nil,
      )
      activate
    end
  end

  def activate_after_passing_in_person
    transaction do
      update!(
        fraud_review_pending_at: nil,
        fraud_rejection_at: nil,
        fraud_pending_reason: nil,
        deactivation_reason: nil,
        in_person_verification_pending_at: nil,
      )
      activate
    end
  end

  def activate_after_password_reset
    if password_reset?
      transaction do
        update!(
          deactivation_reason: nil,
        )
        activate(reason_deactivated: :password_reset)
      end
    end
  end

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  def has_fraud_deactivation_reason?
    fraud_review_pending? || fraud_rejection?
  end

  def in_person_verification_pending?
    in_person_verification_pending_at.present?
  end

  def deactivate_for_in_person_verification
    update!(active: false, in_person_verification_pending_at: Time.zone.now)
  end

  def deactivate_for_gpo_verification
    update!(active: false, gpo_verification_pending_at: Time.zone.now)
  end

  def deactivate_for_fraud_review
    fraud_review
    update!(active: false)
  end

  # possibly redundant
  def bump_fraud_review_pending_timestamps
    update!(
      fraud_review_pending_at: Time.zone.now,
      fraud_rejection_at: nil,
    )
  end

  def reject_for_fraud(notify_user:)
    fraud_reject
    update!(active: false)
    track_fraud_review_adjudication(
      decision: notify_user ? 'manual_reject' : 'automatic_reject',
    )
    UserAlerts::AlertUserAboutAccountRejected.call(user) if notify_user
  end

  def decrypt_pii(password)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)

    encrypted_pii_ciphertext_pair = Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: encrypted_pii,
      multi_region_ciphertext: encrypted_pii_multi_region,
    )

    decrypted_json = encryptor.decrypt(encrypted_pii_ciphertext_pair, user_uuid: user.uuid)
    Pii::Attributes.new_from_json(decrypted_json)
  end

  # @return [Pii::Attributes]
  def recover_pii(personal_key)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)

    encrypted_pii_recovery_ciphertext_pair = Encryption::RegionalCiphertextPair.new(
      single_region_ciphertext: encrypted_pii_recovery,
      multi_region_ciphertext: encrypted_pii_recovery_multi_region,
    )

    decrypted_recovery_json = encryptor.decrypt(
      encrypted_pii_recovery_ciphertext_pair, user_uuid: user.uuid
    )
    return nil if JSON.parse(decrypted_recovery_json).nil?
    Pii::Attributes.new_from_json(decrypted_recovery_json)
  end

  # @param [Pii::Attributes] pii
  def encrypt_pii(pii, password)
    encrypt_ssn_fingerprint(pii)
    encrypt_compound_pii_fingerprint(pii)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    self.encrypted_pii, self.encrypted_pii_multi_region = encryptor.encrypt(
      pii.to_json, user_uuid: user.uuid
    )
    encrypt_recovery_pii(pii)
  end

  # @param [Pii::Attributes] pii
  def encrypt_recovery_pii(pii)
    personal_key = personal_key_generator.create
    encryptor = Encryption::Encryptors::PiiEncryptor.new(
      personal_key_generator.normalize(personal_key),
    )
    self.encrypted_pii_recovery, self.encrypted_pii_recovery_multi_region = encryptor.encrypt(
      pii.to_json, user_uuid: user.uuid
    )
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

  def irs_attempts_api_tracker
    @irs_attempts_api_tracker ||= IrsAttemptsApi::Tracker.new
  end

  private

  def confirm_that_profile_can_be_activated!
    raise reason_not_to_activate if reason_not_to_activate
  end

  def track_fraud_review_adjudication(decision:)
    fraud_review_request = user.fraud_review_requests.last
    irs_attempts_api_tracker.fraud_review_adjudicated(
      decision: decision,
      cached_irs_session_id: fraud_review_request&.irs_session_id,
      cached_login_session_id: fraud_review_request&.login_session_id,
    )
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
