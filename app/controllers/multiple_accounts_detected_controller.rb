# frozen_string_literal: true

class MultipleAccountsDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def show
    @multiple_accounts_detected_presenter = MultipleAccountsDetectedPresenter.new(user: current_user)
    analytics.one_account_multiple_accounts_detected
  end

  def skip
    analytics.one_account_unknown_account_detected
    redirect_to after_sign_in_path_for(current_user)
  end

  def recognize_accounts
    analytics.one_account_recognize_all_accounts
    redirect_to after_sign_in_path_for(current_user)
  end
end
  