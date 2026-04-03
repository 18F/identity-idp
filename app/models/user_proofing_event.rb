# frozen_string_literal: true

class UserProofingEvent < ApplicationRecord
  # @param [String] issuer Client ID of service provider to add to "sent" list
  def add_sp_sent(issuer)
    return if self.service_providers_sent.include? issuer

    self.service_providers_sent.push(issuer)
    self.save!
  end

  # @param [String] new_events Stringified encrypted_events from a UserProofingEvent
  def update_encrypted_events(new_events)
    new_events_json = JSON.parse(new_events)

    self.encrypted_events = new_events
    self.cost = new_events_json['cost']
    self.salt = new_events_json['salt']
    self.save!
  end
end
