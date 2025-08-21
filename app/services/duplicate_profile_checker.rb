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
    if associated_profiles.present?
      ids = associated_profiles.map(&:id)
      existing_profile = DuplicateProfile.involving_profile(
        profile_id: profile.id,
        service_provider: sp.issuer,
      )
      if existing_profile
        if ids.empty?
          existing_profile.update(closed_at: Time.zone.now)
          analytics.one_account_duplicate_profile_closed(
            service_provider: sp.issuer,
          )
        elsif existing_profile.profile_ids != ids + [profile.id]
          # Update existing profile with new ids if they differ
          existing_profile.update(profile_ids: ids + [profile.id])
          analytics.one_account_duplicate_profile_updated(
            service_provider: sp.issuer,
          )
        end
      else
        DuplicateProfile.create(profile_ids: ids + [profile.id], service_provider: sp.issuer)
        analytics.one_account_duplicate_profile_created(
          service_provider: sp.issuer,
          user_uuid: user.uuid,
        )
      end
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
