# frozen_string_literal: true

class DuplicateProfile < ApplicationRecord
  scope :open, -> { where(closed_at: nil) }

  def self.involving_profile(profile_id:, service_provider:)
    where(service_provider: service_provider)
      .where('? = ANY(profile_ids)', profile_id).first
  end
end
