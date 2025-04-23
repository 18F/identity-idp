# frozen_string_literal: true

class DuplicateProfileChecker
  attr_reader :user, :user_session, :sp, :profile

  def initialize(user:, user_session:, sp:)
    @user = user
    @user_session = user_session
    @sp = sp
    @profile = user&.active_profile
  end

  def validate_user_does_not_have_duplicate_profile
    return unless sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    return if user_profile_already_validated?
    cacher = Pii::Cacher.new(user, user_session)
    pii = cacher.fetch(profile.id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])

    if !duplicate_ssn_finder.ssn_is_unique?
      DuplicateProfileConfirmation.create(
        profile_id: profile.id,
        confirmed_at: Time.zone.now,
        duplicate_profile_ids: duplicate_ssn_finder.associated_profiles_with_matching_ssn.map(&:id),
      )
    end

    profile.has_been_checked_for_duplicate_profiles
  end

  private

  def sp_eligible_for_one_account?
    sp.present? && IdentityConfig.store.eligible_one_account_providers.include?(sp.issuer)
  end

  def user_already_verified?
    profile.verify_profile_one_account_at.present?
  end

  def user_has_ial2_profile?
    user.identity_verified_with_facial_match?
  end
end
