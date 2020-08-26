# rubocop:disable Rails/UniqueValidationWithoutIndex
class Authorization < ApplicationRecord
  belongs_to :user
  validates :user_id, :uid, :provider, presence: true
  validates :uid, uniqueness: { scope: :provider, case_sensitive: false }

  AAL2 = 2
  AAL3 = 3
end
# rubocop:enable Rails/UniqueValidationWithoutIndex
