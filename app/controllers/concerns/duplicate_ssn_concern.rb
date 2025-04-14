# frozen_string_literal: true

module DuplicateSsnConcern
  def check_if_user_contains_duplicate_ssn
    return unless IdentityConfig.store.duplicate_ssn_auth_check_enabled
    return unless sp_eligible_for_one_account
    return unless user_already_verified


  end


  private


  def sp_eligible_for_one_account

  end


  def user_already_verified

  end
end
  