# == Schema Information
#
# Table name: proofing_components
#
#  id                           :bigint           not null, primary key
#  address_check                :string
#  device_fingerprinting_vendor :string
#  document_check               :string
#  document_type                :string
#  liveness_check               :string
#  resolution_check             :string
#  source_check                 :string
#  threatmetrix                 :boolean
#  threatmetrix_policy_score    :string
#  threatmetrix_review_status   :string
#  threatmetrix_risk_rating     :string
#  verified_at                  :datetime
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  user_id                      :integer          not null
#
# Indexes
#
#  index_proofing_components_on_user_id      (user_id) UNIQUE
#  index_proofing_components_on_verified_at  (verified_at)
#
class ProofingComponent < ApplicationRecord
  belongs_to :user
end
