class Authorization < ApplicationRecord
  belongs_to :user
  validates :user_id, :uid, :provider, presence: true
  validates :uid, uniqueness: { scope: :provider, case_sensitive: false }

  AAL3 = 3
end
