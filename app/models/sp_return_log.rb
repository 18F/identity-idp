class SpReturnLog < ApplicationRecord
  # rubocop:disable Rails/InverseOf
  belongs_to :user
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf
end

# == Schema Information
#
# Table name: sp_return_logs
#
#  id           :bigint           not null, primary key
#  billable     :boolean
#  ial          :integer          not null
#  issuer       :string           not null
#  requested_at :datetime         not null
#  returned_at  :datetime
#  request_id   :string           not null
#  user_id      :integer
#
# Indexes
#
#  index_sp_return_logs_on_request_id                (request_id) UNIQUE
#  index_sp_return_logs_on_requested_at_date_issuer  (((requested_at)::date), issuer) WHERE (returned_at IS NOT NULL)
#
