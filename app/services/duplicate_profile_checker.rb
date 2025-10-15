# frozen_string_literal: true

class DuplicateProfileChecker
  attr_reader :user, :user_session, :sp, :profile, :analytics

  def initialize(user:, user_session:, sp:, analytics:)
    @user = user
    @user_session = user_session
    @sp = sp
    @analytics = analytics
    @profile = user&.active_profile
  end

  def dupe_profile_set_for_user
    return unless should_check_for_duplicates?

    ssn = fetch_ssn
    return unless ssn

    associated_profiles = find_duplicate_profiles(ssn)
    # If we found associated profiles, create or update the DuplicateProfileSet record
    if associated_profiles.present?
      handle_duplicate_profiles_found(associated_profiles)
    # If no associated profiles found, close out any existing duplicate profile record
    else
      close_existing_duplicate_if_present
    end
  end

  private

  def find_duplicate_profiles(ssn)
    Idv::DuplicateSsnFinder
      .new(user: user, ssn: ssn)
      .duplicate_facial_match_profiles(service_provider: sp.issuer)
  end

  def close_existing_duplicate_if_present
    existing_profile = DuplicateProfileSet.involving_profile(
      profile_id: profile.id,
      service_provider: sp.issuer,
    )

    return unless existing_profile.present?
    # Close out existing duplicate profile if no more duplicates found
    existing_profile.update!(closed_at: Time.zone.now, self_serviced: true)
    analytics.one_account_duplicate_profile_closed
  end

  def handle_duplicate_profiles_found(associated_profiles)
    new_profiles_ids = (associated_profiles.map(&:id) + [profile.id]).uniq.sort

    find_or_create_duplicate_profile(new_profiles_ids)
  end

  def find_or_create_duplicate_profile(new_profile_ids)
    existing_set = find_existing_duplicate_profile_set(new_profile_ids)

    if existing_set.present?
      # Update existing record if profile_ids have changed
      update_existing_duplicate_set(existing_set, new_profile_ids)
    else
      # Create new record with proper conflict handling
      create_duplicate_profile_set(new_profile_ids)
    end
  end

  def find_existing_duplicate_profile_set(profile_ids)
    DuplicateProfileSet.involving_profiles(
      profile_ids: profile_ids,
      service_provider: sp.issuer,
    )
  end

  def update_existing_duplicate_set(existing, new_profile_ids)
    return existing if existing.profile_ids.sort == new_profile_ids.sort

    existing.update!(profile_ids: new_profile_ids)
    analytics.one_account_duplicate_profile_updated
    existing
  end

  def create_duplicate_profile_set(profile_ids)
    set = DuplicateProfileSet.create(
      service_provider: sp&.issuer,
      profile_ids: profile_ids,
    )
    analytics.one_account_duplicate_profile_created
    set
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error do
      "Duplicate Profile Set Duplicate found already, may be closed #{e.message}"
    end

    analytics.one_account_duplicate_profile_creation_failed(
      service_provider: sp&.issuer,
      profile_ids: profile_ids,
      error_message: e.message,
    )
    nil
  end

  def user_has_ial2_profile?
    user.identity_verified_with_facial_match?
  end

  def should_check_for_duplicates?
    user_has_ial2_profile? && user_sp_eligible_for_one_account?
  end

  def fetch_ssn
    cacher = Pii::Cacher.new(user, user_session)

    pii = cacher.fetch(profile.id)
    pii&.dig(:ssn)
  end

  def user_sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp&.issuer)
  end
end
