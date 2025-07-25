# frozen_string_literal: true

class DuplicateProfileChecker
  attr_reader :user, :user_session, :sp, :profile, :type

  def initialize(user:, user_session:, sp:)
    @user = user
    @user_session = user_session
    @sp = sp
    @profile = user&.active_profile
    @type = type
  end

  def check_for_duplicate_profiles
    return unless user_has_ial2_profile? && user_sp_eligible_for_one_account?
    cacher = Pii::Cacher.new(user, user_session)

    pii = cacher.fetch(profile.id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])
    associated_profiles = duplicate_ssn_finder.associated_facial_match_profiles_with_ssn
    if !duplicate_ssn_finder.ial2_profile_ssn_is_unique?
      ids = associated_profiles.map(&:id)
      user_session[:duplicate_profile_ids] = ids
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
