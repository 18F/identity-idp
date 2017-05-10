class VerifyController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_needed, only: %i[cancel fail]

  def index
    if active_profile?
      redirect_to verify_activated_path
    elsif idv_attempter.exceeded?
      redirect_to verify_fail_url
    elsif pending_profile?
      redirect_to account_url
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
    end
  end

  def activated
    redirect_to verify_url unless active_profile?
    idv_attempter.reset
    idv_session.clear
  end

  def fail
    redirect_to verify_url unless ok_to_fail?
  end

  private

  def active_profile?
    current_user.active_profile.present?
  end

  def pending_profile?
    current_user.decorate.pending_profile?
  end

  def ok_to_fail?
    idv_attempter.exceeded? || flash[:max_attempts_exceeded]
  end
end
