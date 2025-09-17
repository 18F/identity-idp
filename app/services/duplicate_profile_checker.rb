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

    pii = get_pii_for_context
    return unless pii.dig(:ssn)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])
    associated_profiles = duplicate_ssn_finder.duplicate_facial_match_profiles(
      service_provider: sp.issuer,
    )

    if associated_profiles.present?
      handle_duplicate_profiles_found(associated_profiles)
    else
      existing_profile = DuplicateProfileSet.involving_profile(
        profile_id: profile.id,
        service_provider: sp.issuer,
      )
      if existing_profile.present?
        # Close out existing duplicate profile if no more duplicates found
        existing_profile.update!(closed_at: Time.zone.now, self_serviced: true)
        analytics.one_account_duplicate_profile_closed
      end
    end
  end

  private

  def handle_duplicate_profiles_found(associated_profiles)
    profile_ids = (associated_profiles.map(&:id) + [profile.id]).uniq.sort

    find_or_create_duplicate_profile(profile_ids)
  end

  def find_or_create_duplicate_profile(profile_ids)
    existing_duplicate = find_existing_duplicate_profile(profile_ids)

    if existing_duplicate
      # Merge profile_ids if we found an existing record
      merged_ids = (existing_duplicate.profile_ids + profile_ids).uniq.sort
      if existing_duplicate.profile_ids.sort != merged_ids
        existing_duplicate.update!(profile_ids: merged_ids)
        analytics.one_account_duplicate_profile_updated
      end
      return existing_duplicate
    end

    # Create new record with proper conflict handling
    create_duplicate_profile(profile_ids)
  end

  def find_existing_duplicate_profile(profile_ids)
    DuplicateProfileSet.involving_profiles(
      profile_ids: profile_ids,
      service_provider: sp.issuer,
    )
  end

  def create_duplicate_profile(profile_ids)
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

  def get_pii_for_context
    cacher = Pii::Cacher.new(user, user_session)

    cacher.fetch(profile.id)
  end

  def user_sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp&.issuer)
  end
end
