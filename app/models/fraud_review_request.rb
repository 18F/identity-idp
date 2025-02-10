# frozen_string_literal: true

class FraudReviewRequest < ApplicationRecord
  include NonNullUuid

  belongs_to :user
end
