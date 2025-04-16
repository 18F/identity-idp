# frozen_string_literal: true

module DuplicateSsnConcern
  def check_if_user_contains_duplicate_ssn
    return unless IdentityConfig.store.duplicate_ssn_auth_check_enabled && sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    return if user_already_verified?

    cacher = Pii::Cacher.new(current_user, user_session)
    pii = cacher.fetch(current_user&.active_profile&.id)
    if !(DuplicateSsnFinder.new(user: current_user, ssn: pii[:ssn]).ssn_is_unique?)
      # add record fr duplicate ssn. 
    end
  end


  private


  def sp_eligible_for_one_account?
    return false unless sp_session.present?
    IdentityConfig.store.eligible_one_account_providers == sp_from_sp_session&.friendly_name
  end


  def user_already_verified?
    false
  end

  def user_has_ial2_profile?
    current_user.identity_verified_with_facial_match?
  end
end
  