class SpCost < ApplicationRecord
end

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: sp_costs
#
#  id             :bigint           not null, primary key
#  cost_type      :string           not null
#  ial            :integer
#  issuer         :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  agency_id      :integer          not null
#  transaction_id :string
#
# Indexes
#
#  index_sp_costs_on_created_at  (created_at)
#
# rubocop:enable Layout/LineLength
