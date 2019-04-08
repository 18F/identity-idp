class Throttle < ApplicationRecord
  belongs_to :user
  validates :user_id, presence: true

  enum throttle_type: {
    idv_acuant: 1,
  }
end
