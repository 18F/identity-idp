# rubocop:disable Rails/UniqueValidationWithoutIndex
class Authorization < ApplicationRecord
  belongs_to :user
  validates :user_id, :uid, :provider, presence: true
  validates :uid, uniqueness: { scope: :provider, case_sensitive: false }

  AAL2 = Idp::Constants::AAL2
  AAL3 = Idp::Constants::AAL3
end
# rubocop:enable Rails/UniqueValidationWithoutIndex
