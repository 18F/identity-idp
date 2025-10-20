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
      close_existing_duplicate_set_if_present
    end
  end

  private

  def find_duplicate_profiles(ssn)
    Idv::DuplicateSsnFinder
      .new(user: user, ssn: ssn)
      .duplicate_facial_match_profiles(service_provider: sp.issuer)
  end

  def close_existing_duplicate_set_if_present
    existing_duplicate_profile_set = DuplicateProfileSet.involving_profile(
      profile_id: profile.id,
      service_provider: sp.issuer,
    )

    return unless existing_duplicate_profile_set.present?
    existing_duplicate_profile_set.update!(closed_at: Time.zone.now, self_serviced: true)
    analytics.one_account_duplicate_profile_closed
  end

  def handle_duplicate_profiles_found(associated_profiles)
    new_profiles_ids = (associated_profiles.map(&:id) + [profile.id]).uniq.sort

    find_or_create_duplicate_profile_set(new_profiles_ids)
  end

  def find_or_create_duplicate_profile_set(new_profile_ids)
    existing_duplicate_profile_set = find_existing_duplicate_profile_set(new_profile_ids)
    if existing_duplicate_profile_set.present?
      # Update existing record if profile_ids have changed
      update_existing_duplicate_set(existing_duplicate_profile_set, new_profile_ids)
    else
      # Create new record with proper conflict handling
      create_duplicate_profile_set(new_profile_ids)
    end
  end

  def find_existing_duplicate_profile_set(profile_ids)
    DuplicateProfileSet.set_for_profiles_and_service_provider(
      profile_ids: profile_ids,
      service_provider: sp.issuer,
    )
  end

  def update_existing_duplicate_set(existing_duplicate_profile_set, new_profile_ids)
    if existing_duplicate_profile_set.closed_at.present?
      reopen_existing_duplicate_set(existing_duplicate_profile_set)
    end

    if existing_duplicate_profile_set.profile_ids.sort != new_profile_ids.sort
      existing_duplicate_profile_set.update!(profile_ids: new_profile_ids)
      analytics.one_account_duplicate_profile_updated
    end
    existing_duplicate_profile_set if existing_duplicate_profile_set.open?
  end

  def reopen_existing_duplicate_set(existing_duplicate_profile_set)
    existing_duplicate_profile_set.update!(closed_at: nil, self_serviced: false)
    analytics.one_account_duplicate_profile_reopened(
      duplicate_profile_set_id: existing_duplicate_profile_set.id,
    )
  end

  def create_duplicate_profile_set(profile_ids)
    set = DuplicateProfileSet.create(
      service_provider: sp&.issuer,
      profile_ids: profile_ids,
    )
    analytics.one_account_duplicate_profile_created
    set
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
