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

  STATUS_ESTABLISHING = 'establishing'
  STATUS_PENDING = 'pending'
  STATUS_PASSED = 'passed'
  STATUS_FAILED = 'failed'
  STATUS_EXPIRED = 'expired'
  STATUS_CANCELLED = 'cancelled'

  enum status: {
    STATUS_ESTABLISHING.to_sym => 0,
    STATUS_PENDING.to_sym => 1,
    STATUS_PASSED.to_sym => 2,
    STATUS_FAILED.to_sym => 3,
    STATUS_EXPIRED.to_sym => 4,
    STATUS_CANCELLED.to_sym => 5,
  }

  validate :profile_belongs_to_user

  before_save(:on_status_updated, if: :will_save_change_to_status?)
  before_save(:on_notification_sent_at_updated, if: :will_save_change_to_notification_sent_at?)
  before_create(:set_unique_id, unless: :unique_id)

  class << self
    def needs_early_email_reminder(early_benchmark, late_benchmark)
      is_pending_and_established_between(
        early_benchmark,
        late_benchmark,
      ).where(early_reminder_sent: false)
    end

    def needs_late_email_reminder(early_benchmark, late_benchmark)
      is_pending_and_established_between(
        early_benchmark,
        late_benchmark,
      ).where(late_reminder_sent: false)
    end

    # Find enrollments that need a status check via the USPS API
    def needs_usps_status_check(check_interval)
      where(status: :pending).
        and(
          where(last_batch_claimed_at: check_interval).
          or(where(last_batch_claimed_at: nil)),
        )
    end

    def needs_usps_status_check_batch(batch_at)
      where(status: :pending).
        and(
          where(last_batch_claimed_at: batch_at),
        ).
        order(status_check_attempted_at: :asc)
    end

    # Find enrollments that are ready for a status check via the USPS API
    def needs_status_check_on_ready_enrollments(check_interval)
      needs_usps_status_check(check_interval).where(ready_for_status_check: true)
    end

    # Find waiting enrollments that need a status check via the USPS API
    def needs_status_check_on_waiting_enrollments(check_interval)
      needs_usps_status_check(check_interval).where(ready_for_status_check: false)
    end

    # Generates a random 18-digit string, the hex returns a string of length n*2
    def generate_unique_id
      SecureRandom.hex(9)
    end

    private

    def is_pending_and_established_between(early_benchmark, late_benchmark)
      where(status: :pending).
        and(
          where(enrollment_established_at: late_benchmark...(early_benchmark.end_of_day)),
        ).
        order(enrollment_established_at: :asc)
    end
  end
  # end class methods

  # Does this enrollment need a status check via the USPS API?
  def needs_usps_status_check?(check_interval)
    pending? && (
      last_batch_claimed_at.nil? ||
      check_interval.cover?(last_batch_claimed_at)
    )
  end

  # Does this ready enrollment need a status check via the USPS API?
  def needs_status_check_on_ready_enrollment?(check_interval)
    needs_usps_status_check?(check_interval) && ready_for_status_check?
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

  def due_date
    start_date = enrollment_established_at.presence || created_at
    start_date + IdentityConfig.store.in_person_enrollment_validity_in_days.days
  end

  def days_to_due_date
    today = Time.zone.now
    (due_date - today).seconds.in_days.to_i
  end

  def eligible_for_notification?
    notification_phone_configuration.present? && (passed? || failed?)
  end

  # (deprecated) Returns the value to use for the USPS enrollment ID
  def usps_unique_id
    user.uuid.delete('-').slice(0, 18)
  end

  private

  def on_notification_sent_at_updated
    change_will_be_saved = notification_sent_at_change_to_be_saved&.last.present?
    if change_will_be_saved && notification_phone_configuration.present?
      notification_phone_configuration.destroy
    end
  end

  def on_status_updated
    if enrollment_will_be_cancelled_or_expired? && notification_phone_configuration.present?
      notification_phone_configuration.destroy!
    end
    self.status_updated_at = Time.zone.now
  end

  def enrollment_will_be_cancelled_or_expired?
    [STATUS_CANCELLED, STATUS_EXPIRED].include? status_change_to_be_saved&.last
  end

  def set_unique_id
    self.unique_id = InPersonEnrollment.generate_unique_id
  end

  def profile_belongs_to_user
    return unless profile.present?

    unless profile.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end
end
