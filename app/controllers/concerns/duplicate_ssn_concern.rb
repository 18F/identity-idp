# frozen_string_literal: true

module DuplicateSsnConcern
  def validate_user_does_not_have_duplicate_ssn
    return unless sp_eligible_for_one_account?
    return unless user_has_ial2_profile?
    return if user_already_verified?

    cacher = Pii::Cacher.new(current_user, user_session)
    pii = cacher.fetch(current_user&.active_profile&.id)
    if !(Idv::DuplicateSsnFinder.new(user: current_user, ssn: pii[:ssn]).ssn_is_unique?)
      
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
  