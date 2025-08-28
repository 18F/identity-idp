# frozen_string_literal: true

class DuplicateProfile < ApplicationRecord
  def self.involving_profiles(profile_ids:, service_provider:)
    where(service_provider: service_provider)
      .where('profile_ids && ?', "{#{profile_ids.join(',')}}")
      .where(closed_at: nil)
      .first
  end

  def self.involving_profile(profile_id:, service_provider:)
    where(service_provider: service_provider)
      .where('? = ANY(profile_ids)', profile_id)
      .where(closed_at: nil)
      .first
  end
end
