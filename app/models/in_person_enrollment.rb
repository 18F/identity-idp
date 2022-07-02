class InPersonEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :profile
  enum status: {
    pending: 0,
    passed: 1,
    failed: 2,
    expired: 3,
    canceled: 4,
  }

  validate :profile_belongs_to_user

  # Find enrollments that need a status check via the USPS API
  def self.needs_usps_status_check check_interval
    where(status: :pending).
    and(
      where(status_check_attempted_at: check_interval).
      or where(status_check_attempted_at: nil)
    ).
    order(status_check_attempted_at: :asc)
  end

  # Does this enrollment need a status check via the USPS API?
  def needs_usps_status_check? check_interval
    status == :pending && (
      status_check_attempted_at == nil ||
      check_interval.cover?(status_check_attempted_at)
    )
  end

  # Returns a compressed version of the user's ID for use with the USPS API
  # This is reversible for IDs under about 70 quadrillion
  def usps_enrollment_id
    return nil if user_id == nil

    [
      ("%014X" % (user_id)). # Encode User ID to Hex & pad with 0's to 14 characters ~ 70 quadrillion
      scan(/../).map(&:hex). # Parse each pair of characters into a Ruby integer array
      pack("c*") # Convert integer array into a string, treating each element as a signed char
    ].pack('m*'). # Encode to Base64
    tr('+/', '-_'). # Replace "+" and "/" with "-" and "_" respectively
    sub(/=*\n?\Z/,'') # Trim Base64 Padding
  end

  private

  def profile_belongs_to_user
    unless profile&.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end
end
