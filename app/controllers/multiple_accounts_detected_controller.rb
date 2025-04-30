# frozen_string_literal: true

class MultipleAccountsDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile_confirmation

  def show
    @multiple_accounts_detected_presenter = MultipleAccountsDetectedPresenter.new(user: current_user)
    analytics.one_account_multiple_accounts_detected
  end

  def do_not_recognize
    analytics.one_account_unknown_account_detected
    duplicate_profile_confirmation.mark_some_accounts_not_recognized
    redirect_to after_sign_in_path_for(current_user)
  end

  def recognize_accounts
    analytics.one_account_recognize_all_accounts
    duplicate_profile_confirmation.mark_all_accounts_recognized
    redirect_to after_sign_in_path_for(current_user)
  end

  private 

  def redirect_unless_user_has_active_duplicate_profile_confirmation
    if current_user&.active_profile.present?
      if duplicate_profile_confirmation && duplicate_profile_confirmation&.confirmed_all == nil
        return
      end
    end
    redirect_to after_sign_in_path_for(current_user)
  end


  def duplicate_profile_confirmation 
    return unless current_user.active_profile
    @duplicate_profile_confirmation ||= DuplicateProfileConfirmation.find_by(
      profile_id: current_user.active_profile.id
    )
  end
end
  