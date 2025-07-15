# frozen_string_literal: true

class SpReturnLog < ApplicationRecord
  # rubocop:disable Rails/InverseOf
  belongs_to :user
  belongs_to :service_provider,
             foreign_key: 'issuer',
             primary_key: 'issuer'
  belongs_to :profile_requested_service_provider,
             class_name: 'ServiceProvider',
             foreign_key: 'profile_requested_issuer',
             primary_key: 'issuer'
  belongs_to :profile
  # rubocop:enable Rails/InverseOf
end
