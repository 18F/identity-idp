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

  # Cross-SP variant: find an open set involving a profile where service_provider is NULL.
  # Used when one_account_enforcement_mode is ial2_cross_sp_all_sps.
  def self.involving_profile_any_sp(profile_id:)
    open
      .where(service_provider: nil)
      .where('? = ANY(profile_ids)', profile_id)
      .first
  end

  # Cross-SP variant: find a set with overlapping profile_ids where service_provider is NULL.
  # Used when one_account_enforcement_mode is ial2_cross_sp_all_sps.
  def self.set_for_profiles(profile_ids:)
    where(service_provider: nil)
      .where('profile_ids && ?', "{#{profile_ids.join(',')}}")
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
