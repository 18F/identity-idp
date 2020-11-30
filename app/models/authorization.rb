# rubocop:disable Rails/UniqueValidationWithoutIndex
class Authorization < ApplicationRecord
  belongs_to :user
  validates :user_id, :uid, :provider, presence: true
  validates :uid, uniqueness: { scope: :provider, case_sensitive: false }
end
# rubocop:enable Rails/UniqueValidationWithoutIndex
