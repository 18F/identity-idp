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

  def check_for_duplicate_profiles
    return unless user_has_ial2_profile? && user_sp_eligible_for_one_account?
    cacher = Pii::Cacher.new(user, user_session)

    pii = cacher.fetch(profile.id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])
    associated_profiles = duplicate_ssn_finder.duplicate_facial_match_profiles(
      service_provider: sp.issuer,
    )
    ids = associated_profiles.map(&:id)
    dupe_profile_ids = (ids + [profile.id]).sort
    existing_profile = DuplicateProfile.involving_profiles(
      profile_ids: dupe_profile_ids,
      service_provider: sp.issuer,
    )
    if associated_profiles.present?
      if existing_profile
        if existing_profile.profile_ids.sort != dupe_profile_ids
          # Update existing profile with new ids if they differ
          existing_profile.update(profile_ids: dupe_profile_ids)
          analytics.one_account_duplicate_profile_updated
        end
      else
        existing_profile = DuplicateProfile.create(
          profile_ids: dupe_profile_ids,
          service_provider: sp.issuer,
        )
        analytics.one_account_duplicate_profile_created
      end
      existing_profile
    elsif existing_profile
      existing_profile.update(closed_at: Time.zone.now)
      analytics.one_account_duplicate_profile_closed
    end
  end

  private

  def user_has_ial2_profile?
    user.identity_verified_with_facial_match?
  end

  def user_sp_eligible_for_one_account?
    IdentityConfig.store.eligible_one_account_providers.include?(sp&.issuer)
  end
end
