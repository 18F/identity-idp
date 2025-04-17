# frozen_string_literal: true

class DuplicateProfileChecker

  attr_reader :user, :user_session, :sp

  def initialize(user:, user_session:, sp:)
    @user = user
    @user_session = user_session
    @sp = sp 
  end


  def validate_user_does_not_have_duplicate_profile
    return unless sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    return if user_already_verified?
    
    cacher = Pii::Cacher.new(user, user_session)
    profile_id = user&.active_profile&.id
    pii = cacher.fetch(profile_id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user:, ssn: pii[:ssn])
    if !(duplicate_ssn_finder.ssn_is_unique?)
      duplicate_profile_confirmation = DuplicateProfileConfirmation.create(
        profile_id: profile_id,
        confirmed_at: Time.zone.now,
        duplicate_profiles: duplicate_ssn_finder.associated_profiles_with_matching_ssn.map(&:id),
      )
    end
  end


  private


  def sp_eligible_for_one_account?
    return false unless sp.present?
    IdentityConfig.store.eligible_one_account_providers.include?(sp&.friendly_name)
  end


  def user_already_verified?
    false
  end

  def user_has_ial2_profile?
    user.identity_verified_with_facial_match?
  end
end
    