# frozen_string_literal: true

class Profile < ApplicationRecord
  # IDV levels equivalent to facial match
  FACIAL_MATCH_IDV_LEVELS = %w[unsupervised_with_selfie in_person].to_set.freeze
  # Facial match through IAL2 opt-in flow
  FACIAL_MATCH_OPT_IN = %w[unsupervised_with_selfie].to_set.freeze

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

  enum :deactivation_reason, {
    password_reset: 1,
    encryption_error: 2,
    gpo_verification_pending_NO_LONGER_USED: 3, # deprecated
    verification_cancelled: 4,
    in_person_verification_pending_NO_LONGER_USED: 5, # deprecated
  }

  enum :fraud_pending_reason, {
    threatmetrix_review: 1,
    threatmetrix_reject: 2,
  }

  enum :idv_level, {
    legacy_unsupervised: 1,
    legacy_in_person: 2,
    unsupervised_with_selfie: 3,
    in_person: 4,
  }

  attr_reader :personal_key

  # Class methods
  def self.active
    where(active: true)
  end

  def self.verified
    where.not(verified_at: nil)
  end

  def self.facial_match
    where(idv_level: FACIAL_MATCH_IDV_LEVELS)
  end

  def self.facial_match_opt_in
    where(idv_level: FACIAL_MATCH_OPT_IN)
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
      *(:fraud_check_pending if fraud_deactivation_reason?),
      *(:in_person_verification_pending if in_person_verification_pending?),
    ]
  end

  # rubocop:disable Rails/SkipsModelValidations
  def activate(reason_deactivated: nil)
    confirm_that_profile_can_be_activated!

    now = Time.zone.now
    profile_to_deactivate = Profile.find_by(user_id: user_id, active: true)
    is_reproof = profile_to_deactivate.present?
    is_facial_match_upgrade = is_reproof && facial_match? && !profile_to_deactivate.facial_match?

    attrs = {
      active: true,
      activated_at: now,
    }

    attrs[:verified_at] = now unless reason_deactivated == :password_reset || verified_at

    transaction do
      Profile.where(user_id: user_id).where.not(id:).update_all(active: false)
      reload
      update!(attrs)
    end

    user.analytics.idv_profile_activated(
      idv_level:,
      issuer: initiating_service_provider&.issuer,
      verified_at:,
      activated_at:,
    )

    track_facial_match_reproof if is_facial_match_upgrade
    send_push_notifications if is_reproof
  end
  # rubocop:enable Rails/SkipsModelValidations

  def tmx_status
    return nil unless IdentityConfig.store.in_person_proofing_enforce_tmx
    return nil unless FeatureManagement.proofing_device_profiling_decisioning_enabled?

    fraud_pending_reason || :threatmetrix_pass
  end

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
      update!(
        fraud_review_pending_at: nil,
        fraud_rejection_at: nil,
        fraud_pending_reason: nil,
      )
      activate
    end
  end

  def activate_after_fraud_review_unnecessary
    transaction do
      update!(
        fraud_review_pending_at: nil,
        fraud_rejection_at: nil,
        fraud_pending_reason: nil,
      )
      activate
    end
  end

  def activate_after_passing_in_person
    transaction do
      update!(
        in_person_verification_pending_at: nil,
      )
      activate
    end
  end

  # Removes the deactivation reason from the profile if it had a password_reset
  # deactivation reason. If the profile was activated previously it will be
  # reactivated.
  def clear_password_reset_deactivation_reason
    if password_reset?
      transaction do
        update!(deactivation_reason: nil)
        activate(reason_deactivated: :password_reset) if activated_at.present?
      end
    end
  end

  def deactivate(reason)
    update!(active: false, deactivation_reason: reason)
  end

  # Update the profile's deactivation reason to "encryption_error". As a
  # side-effect, when the profile has an associated pending in-person
  # enrollment it will be updated to have a status of "cancelled".
  def deactivate_due_to_encryption_error
    update!(
      active: false,
      deactivation_reason: :encryption_error,
    )

    if in_person_enrollment&.pending?
      in_person_enrollment.cancelled!
    end
  end

  def fraud_deactivation_reason?
    fraud_review_pending? || fraud_rejection?
  end

  def in_person_verification_pending?
    in_person_verification_pending_at.present?
  end

  def deactivate_due_to_gpo_expiration
    raise 'Profile is not pending GPO verification' if gpo_verification_pending_at.nil?
    update!(
      active: false,
      gpo_verification_pending_at: nil,
      gpo_verification_expired_at: Time.zone.now,
    )
  end

  def deactivate_due_to_in_person_verification_cancelled
    update!(
      active: false,
      in_person_verification_pending_at: nil,
      deactivation_reason: deactivation_reason.presence || :verification_cancelled,
    )
  end

  def deactivate_for_in_person_verification
    update!(active: false, in_person_verification_pending_at: Time.zone.now)
  end

  def deactivate_for_gpo_verification
    update!(active: false, gpo_verification_pending_at: Time.zone.now)
  end

  def deactivate_for_fraud_review
    update!(
      active: false,
      fraud_review_pending_at: Time.zone.now,
      fraud_rejection_at: nil,
      in_person_verification_pending_at: nil,
    )
  end

  def deactivate_due_to_ipp_expiration_during_fraud_review
    update!(
      active: false,
      in_person_verification_pending_at: nil,
      fraud_rejection_at: Time.zone.now,
    )
  end

  def deactivate_duplicate
    raise 'Profile not active' unless active
    raise 'Profile not a duplicate' unless DuplicateProfileSet.open.exists?(
      ['? = ANY(profile_ids)', id],
    )

    transaction do
      update!(
        active: false,
        fraud_review_pending_at: nil,
        fraud_rejection_at: Time.zone.now,
      )
      DuplicateProfileSet.open.where(['? = ANY(profile_ids)', id]).find_each do |duplicate_profile|
        if duplicate_profile.profile_ids.length > 1
          duplicate_profile.profile_ids.delete(id)
          duplicate_profile.save
        else
          duplicate_profile.update!(
            closed_at: Time.zone.now,
            self_serviced: false,
            fraud_investigation_conclusive: true,
          )
        end

        service_provider = ServiceProvider.find_sole_by(issuer: duplicate_profile.service_provider)
        user.confirmed_email_addresses.each do |email_address|
          mailer = UserMailer.with(user: user, email_address: email_address)
          mailer.dupe_profile_account_review_complete_locked(
            agency_name: service_provider.friendly_name,
          ).deliver_now_or_later
        end
      end
    end
  end

  def clear_duplicate
    raise 'Profile not active' unless active
    raise 'Profile not a duplicate' unless DuplicateProfileSet.open.exists?(
      ['? = ANY(profile_ids)', id],
    )
    raise 'Profile has other duplicates' if DuplicateProfileSet.open.exists?(
      ['? = ANY(profile_ids) AND cardinality(profile_ids) > 1', id],
    )

    transaction do
      DuplicateProfileSet.open.where(['? = ANY(profile_ids)', id]).find_each do |duplicate_profile|
        duplicate_profile.update!(
          closed_at: Time.zone.now,
          self_serviced: false,
          fraud_investigation_conclusive: true,
        )

        service_provider = ServiceProvider.find_sole_by(issuer: duplicate_profile.service_provider)
        user.confirmed_email_addresses.each do |email_address|
          mailer = UserMailer.with(user: user, email_address: email_address)
          mailer.dupe_profile_account_review_complete_success(
            agency_name: service_provider.friendly_name,
          ).deliver_now_or_later
        end
      end
    end
  end

  def close_inconclusive_duplicate
    raise 'Profile not active' unless active
    raise 'Profile not a duplicate' unless DuplicateProfileSet.open.exists?(
      ['? = ANY(profile_ids)', id],
    )

    transaction do
      DuplicateProfileSet.open.where(['? = ANY(profile_ids)', id]).find_each do |duplicate_profile|
        if duplicate_profile.profile_ids.length > 1
          duplicate_profile.profile_ids.delete(id)
          duplicate_profile.save
        else
          duplicate_profile.update!(
            closed_at: Time.zone.now,
            self_serviced: false,
            fraud_investigation_conclusive: false,
          )
        end

        service_provider = ServiceProvider.find_sole_by(issuer: duplicate_profile.service_provider)
        user.confirmed_email_addresses.each do |email_address|
          mailer = UserMailer.with(user: user, email_address: email_address)
          mailer.dupe_profile_account_review_complete_unable(
            agency_name: service_provider.friendly_name,
          ).deliver_now_or_later
        end
      end
    end
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

    decrypted_json = encryptor.decrypt(encrypted_pii_multi_region, user_uuid: user.uuid)
    Pii::Attributes.new_from_json(decrypted_json)
  end

  # @return [Pii::Attributes]
  def recover_pii(personal_key)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)

    decrypted_recovery_json = encryptor.decrypt(
      encrypted_pii_recovery_multi_region, user_uuid: user.uuid
    )
    return nil if JSON.parse(decrypted_recovery_json).nil?
    Pii::Attributes.new_from_json(decrypted_recovery_json)
  end

  # @param [Pii::Attributes] pii
  def encrypt_pii(pii, password)
    encrypt_ssn_fingerprint(pii)
    encrypt_compound_pii_fingerprint(pii)
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    self.encrypted_pii = nil
    self.encrypted_pii_multi_region = encryptor.encrypt(
      pii.to_json, user_uuid: user.uuid
    )
    encrypt_recovery_pii(pii)
  end

  # @param [Pii::Attributes] pii
  def encrypt_recovery_pii(pii, personal_key: nil)
    personal_key ||= personal_key_generator.generate!
    encryptor = Encryption::Encryptors::PiiEncryptor.new(
      personal_key_generator.normalize(personal_key),
    )
    self.encrypted_pii_recovery = nil
    self.encrypted_pii_recovery_multi_region = encryptor.encrypt(
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

  def profile_age_in_seconds
    (Time.zone.now - created_at).round
  end

  def facial_match?
    FACIAL_MATCH_IDV_LEVELS.include?(idv_level)
  end

  private

  def confirm_that_profile_can_be_activated!
    raise reason_not_to_activate if reason_not_to_activate
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

  def track_facial_match_reproof
    SpUpgradedFacialMatchProfile.create(
      user: user,
      upgraded_at: Time.zone.now,
      idv_level: idv_level,
      issuer: initiating_service_provider_issuer,
    )
  end
end
