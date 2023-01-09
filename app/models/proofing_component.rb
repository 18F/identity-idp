class ProofingComponent < ApplicationRecord
  belongs_to :user

  def review_eligible?
    verified_at.after?(30.days.ago)
  end
end
