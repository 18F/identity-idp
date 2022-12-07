require 'securerandom'

class InPersonEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :profile
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer',
             inverse_of: :in_person_enrollments,
             optional: true
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
  before_create(:set_unique_id, unless: :unique_id)

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

  def minutes_since_established
    return unless enrollment_established_at.present?
    (Time.zone.now - enrollment_established_at).seconds.in_minutes.round(2)
  end

  def minutes_since_last_status_check
    return unless status_check_attempted_at.present?
    (Time.zone.now - status_check_attempted_at).seconds.in_minutes.round(2)
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

  private

  def on_status_updated
    self.status_updated_at = Time.zone.now
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
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: in_person_enrollments
#
#  id                                                                                                                                                   :bigint           not null, primary key
#  early_reminder_sent(early reminder to complete IPP before deadline sent)                                                                             :boolean          default(FALSE)
#  enrollment_code(The code returned by the USPS service)                                                                                               :string
#  enrollment_established_at(When the enrollment was successfully established)                                                                          :datetime
#  follow_up_survey_sent                                                                                                                                :boolean          default(FALSE)
#  issuer(Issuer associated with the enrollment at time of creation)                                                                                    :string
#  late_reminder_sent(late reminder to complete IPP before deadline sent)                                                                               :boolean          default(FALSE)
#  selected_location_details(The location details of the Post Office the user selected (including title, address, hours of operation))                  :jsonb
#  status(The status of the enrollment)                                                                                                                 :integer          default("establishing")
#  status_check_attempted_at(The last time a status check was attempted)                                                                                :datetime
#  status_updated_at(The last time the status was successfully updated with a value from the USPS API)                                                  :datetime
#  created_at                                                                                                                                           :datetime         not null
#  updated_at                                                                                                                                           :datetime         not null
#  current_address_matches_id(True if the user indicates that their current address matches the address on the ID they're bringing to the Post Office.) :boolean
#  profile_id(Foreign key to the profile this enrollment belongs to)                                                                                    :bigint
#  unique_id(Unique ID to use with the USPS service)                                                                                                    :string
#  user_id(Foreign key to the user this enrollment belongs to)                                                                                          :bigint           not null
#
# Indexes
#
#  index_in_person_enrollments_on_profile_id          (profile_id)
#  index_in_person_enrollments_on_unique_id           (unique_id) UNIQUE
#  index_in_person_enrollments_on_user_id             (user_id)
#  index_in_person_enrollments_on_user_id_and_status  (user_id,status) UNIQUE WHERE (status = 1)
#
# Foreign Keys
#
#  fk_rails_...  (issuer => service_providers.issuer)
#  fk_rails_...  (profile_id => profiles.id)
#  fk_rails_...  (user_id => users.id)
#
# rubocop:enable Layout/LineLength
