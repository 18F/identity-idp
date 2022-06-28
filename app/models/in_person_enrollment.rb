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

  private

  def profile_belongs_to_user
    unless profile&.user == user
      errors.add :profile, I18n.t('idv.failure.exceptions.internal_error'),
                 type: :in_person_enrollment_user_profile_mismatch
    end
  end
end
