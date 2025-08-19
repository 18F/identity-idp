# frozen_string_literal: true

class DuplicateProfile < ApplicationRecord
  def self.involving_profile(profile_id:, service_provider:)
    where(service_provider: service_provider)
      .where('? = ANY(profile_ids)', profile_id)
  end

  def self.get_profile_info(profile_id:, service_provider:)
    involving_profile(profile_id: profile_id, service_provider: service_provider).first
  end
end
