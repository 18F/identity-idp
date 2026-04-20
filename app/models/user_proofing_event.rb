# frozen_string_literal: true

class UserProofingEvent < ApplicationRecord
  belongs_to :profile

  # @param [String] issuer Client ID of service provider to add to "sent" list
  def add_sp_sent(issuer)
    return if self.service_providers_sent.include? issuer

    self.service_providers_sent.push(issuer)
    self.save!
  end
end
