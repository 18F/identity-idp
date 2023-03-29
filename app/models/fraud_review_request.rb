class FraudReviewRequest < ApplicationRecord
  include NonNullUuid

  belongs_to :user
end
