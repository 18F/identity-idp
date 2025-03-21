# frozen_string_literal: true

class SpReturnLog < ApplicationRecord
  self.ignored_columns = %w[requested_at]

  # rubocop:disable Rails/InverseOf
  belongs_to :user
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  belongs_to :profile_requested_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'profile_requested_issuer',
             primary_key: 'issuer'
  # rubocop:enable Rails/InverseOf
end
