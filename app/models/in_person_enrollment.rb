class InPersonEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :profile
  enum status: {
    establishing: 0,
    pending: 1,
    passed: 2,
    failed: 3,
    expired: 4,
    canceled: 5,
  }

  validate :profile_belongs_to_user

  # Find enrollments that need a status check via the USPS API
  def self.needs_usps_status_check check_interval
    where(status: :pending).
    and(
      where(status_check_attempted_at: check_interval).
      or where(status_check_attempted_at: nil),
    ).
    order(status_check_attempted_at: :asc)
  end

  # Does this enrollment need a status check via the USPS API?
  def needs_usps_status_check? check_interval
    status == :pending && (
      status_check_attempted_at.nil? ||
      check_interval.cover?(status_check_attempted_at)
    )
  end

  # Returns the value to use for the USPS enrollment ID
  def usps_unique_id
    user_id.to_s
  end

  def status=(value)
    self.status_updated_at = Time.now
    super(value)
  end

  private

  def profile_belongs_to_user
    unless profile&.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end
end
