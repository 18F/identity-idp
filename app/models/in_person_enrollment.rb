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

  private

  def profile_belongs_to_user
    unless profile&.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end
end
