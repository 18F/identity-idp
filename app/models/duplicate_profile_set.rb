# frozen_string_literal: true

class DuplicateProfileSet < ApplicationRecord
  scope :open, -> { where(closed_at: nil) }

  def self.set_for_profiles_and_service_provider(profile_ids:, service_provider:)
    where(service_provider: service_provider)
      .where('profile_ids && ?', "{#{profile_ids.join(',')}}")
      .first
  end

  def self.involving_profile(profile_id:, service_provider:)
    open
      .where(service_provider: service_provider)
      .where('? = ANY(profile_ids)', profile_id)
      .first
  end

  def self.duplicate_profile_sets_for_profile(profile_id:)
    open
      .where('? = ANY(profile_ids)', profile_id)
  end

  def open?
    closed_at.nil?
  end
end
