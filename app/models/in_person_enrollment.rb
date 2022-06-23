class InPersonEnrollment < ApplicationRecord
  belongs_to :user
  belongs_to :profile
  enum status: {
    pending: 0,
    passed: 1,
    failed: 2,
    expired: 3,
    canceled: 4
  }

end
