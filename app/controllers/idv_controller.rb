class IdvController < ApplicationController
  include IdvSession
  include AccountReactivationConcern

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_needed, only: %i[cancel fail]
  before_action :profile_needs_reactivation?, only: [:index]

  def index
    if active_profile?
      redirect_to idv_activated_url
    elsif idv_attempter.exceeded?
      redirect_to idv_fail_url
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
    end
  end

  def activated
    redirect_to idv_url unless active_profile?
    idv_attempter.reset
    idv_session.clear
  end

  def cancel; end

  def fail
    redirect_to idv_url unless ok_to_fail?
  end

  private

  def profile_needs_reactivation?
    return unless reactivate_account_session.started?
    confirm_password_reset_profile
    redirect_to reactivate_account_url
  end

  def active_profile?
    current_user.active_profile.present?
  end

  def ok_to_fail?
    idv_attempter.exceeded? || flash[:max_attempts_exceeded]
  end
end
