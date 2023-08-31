require 'securerandom'

class InPersonEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :profile
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer',
             inverse_of: :in_person_enrollments,
             optional: true

  has_one :notification_phone_configuration, dependent: :destroy, inverse_of: :in_person_enrollment

  enum status: {
    establishing: 0,
    pending: 1,
    passed: 2,
    failed: 3,
    expired: 4,
    cancelled: 5,
  }

  validate :profile_belongs_to_user

  before_save(:on_status_updated, if: :will_save_change_to_status?)
  before_save(:on_notification_sent_at_updated, if: :will_save_change_to_notification_sent_at?)
  before_create(:set_unique_id, unless: :unique_id)
  before_create(:set_capture_secondary_id)

  def self.is_pending_and_established_between(early_benchmark, late_benchmark)
    where(status: :pending).
      and(
        where(enrollment_established_at: late_benchmark...(early_benchmark.end_of_day)),
      ).
      order(enrollment_established_at: :asc)
  end

  def self.needs_early_email_reminder(early_benchmark, late_benchmark)
    self.is_pending_and_established_between(
      early_benchmark,
      late_benchmark,
    ).where(early_reminder_sent: false)
  end

  def self.needs_late_email_reminder(early_benchmark, late_benchmark)
    self.is_pending_and_established_between(
      early_benchmark,
      late_benchmark,
    ).where(late_reminder_sent: false)
  end

  # Find enrollments that need a status check via the USPS API
  def self.needs_usps_status_check(check_interval)
    where(status: :pending).
      and(
        where(status_check_attempted_at: check_interval).
        or(where(status_check_attempted_at: nil)),
      ).
      order(status_check_attempted_at: :asc)
  end

  # Does this enrollment need a status check via the USPS API?
  def needs_usps_status_check?(check_interval)
    pending? && (
      status_check_attempted_at.nil? ||
      check_interval.cover?(status_check_attempted_at)
    )
  end

  # Find enrollments that are ready for a status check via the USPS API
  def self.needs_status_check_on_ready_enrollments(check_interval)
    needs_usps_status_check(check_interval).where(ready_for_status_check: true)
  end

  # Does this ready enrollment need a status check via the USPS API?
  def needs_status_check_on_ready_enrollment?(check_interval)
    needs_usps_status_check?(check_interval) && ready_for_status_check?
  end

  # Find waiting enrollments that need a status check via the USPS API
  def self.needs_status_check_on_waiting_enrollments(check_interval)
    needs_usps_status_check(check_interval).where(ready_for_status_check: false)
  end

  # Does this waiting enrollment need a status check via the USPS API?
  def needs_status_check_on_waiting_enrollment?(check_interval)
    needs_usps_status_check?(check_interval) && !ready_for_status_check?
  end

  def minutes_since_established
    return unless enrollment_established_at.present?
    (Time.zone.now - enrollment_established_at).seconds.in_minutes.round(2)
  end

  def minutes_since_last_status_check
    return unless status_check_attempted_at.present?
    (Time.zone.now - status_check_attempted_at).seconds.in_minutes.round(2)
  end

  def minutes_since_last_status_check_completed
    return unless status_check_completed_at.present?
    (Time.zone.now - status_check_completed_at).seconds.in_minutes.round(2)
  end

  def minutes_since_last_status_update
    return unless status_updated_at.present?
    (Time.zone.now - status_updated_at).seconds.in_minutes.round(2)
  end

  # (deprecated) Returns the value to use for the USPS enrollment ID
  def usps_unique_id
    user.uuid.delete('-').slice(0, 18)
  end

  # Generates a random 18-digit string, the hex returns a string of length n*2
  def self.generate_unique_id
    SecureRandom.hex(9)
  end

  def due_date
    start_date = enrollment_established_at.presence || created_at
    start_date + IdentityConfig.store.in_person_enrollment_validity_in_days.days
  end

  def days_to_due_date
    today = DateTime.now
    (today...due_date).count
  end

  def on_notification_sent_at_updated
    if self.notification_sent_at && self.notification_phone_configuration
      self.notification_phone_configuration.destroy
    end
  end

  def skip_notification_sent_at_set?
    !notification_phone_configuration.present? || (!self.passed? && !self.failed? && !self.expired?)
  end

  private

  def on_status_updated
    if enrollment_will_be_cancelled? && notification_phone_configuration.present?
      notification_phone_configuration.destroy!
    end
    self.status_updated_at = Time.zone.now
  end

  def enrollment_will_be_cancelled?
    status_change_to_be_saved&.last == 'cancelled'
  end

  def set_unique_id
    self.unique_id = self.class.generate_unique_id
  end

  def profile_belongs_to_user
    return unless profile.present?

    unless profile.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end

  def set_capture_secondary_id
    if IdentityConfig.store.in_person_capture_secondary_id_enabled
      self.capture_secondary_id_enabled = true
    end
  end
end
