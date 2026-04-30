# frozen_string_literal: true

class UserProofingEvent < ApplicationRecord
  belongs_to :profile
  self.ignored_columns = %w[encrypted_events service_providers_sent]

  # @param [String] id ID of service provider to add to "sent" list
  def add_sp_sent(id)
    return if self.service_provider_ids_sent.include?(id)

    self.service_provider_ids_sent.push(id)
    self.save!
  end
end
