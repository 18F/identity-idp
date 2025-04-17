# frozen_string_literal: true

module DuplicateSsnConcern
  def validate_user_does_not_have_duplicate_ssn
    return unless sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    return if user_already_verified?
    
    cacher = Pii::Cacher.new(current_user, user_session)
    profile_id = current_user&.active_profile&.id
    pii = cacher.fetch(profile_id)
    duplicate_ssn_finder = Idv::DuplicateSsnFinder.new(user: current_user, ssn: pii[:ssn])
    if !(duplicate_ssn_finder.ssn_is_unique?)
      DuplicateProfileConfirmation.create(
        profile_id: profile_id,
        confirmed_at: Time.zone.now,
        duplicate_profiles: duplicate_ssn_finder.associated_profiles_with_matching_ssn,
        confirmed_all: false,
      )
    end
  end


  private


  def sp_eligible_for_one_account?
    return false unless sp_session.present?
    IdentityConfig.store.eligible_one_account_providers.include?(sp_from_sp_session&.friendly_name)
  end


  def user_already_verified?
    false
  end

  def user_has_ial2_profile?
    current_user.identity_verified_with_facial_match?
  end
end
  