# frozen_string_literal: true

class UserProofingEvent < ApplicationRecord
  # @param [String] new_events Stringified encrypted_events from a UserProofingEvent
  def update_encrypted_events(new_events)
    new_events_json = JSON.parse(new_events)

    self.encrypted_events = new_events
    self.cost = new_events_json['cost']
    self.salt = new_events_json['salt']
    self.save!
  end
end
