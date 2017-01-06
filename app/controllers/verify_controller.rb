class VerifyController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated
  before_action :confirm_idv_needed, only: [:cancel, :fail, :retry]

  def index
    if active_profile?
      redirect_to verify_activated_path
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
    end
  end

  def retry
    flash.now[:error] = I18n.t('idv.errors.fail')
  end

  def activated
    redirect_to verify_url unless active_profile?
  end

  def fail
    redirect_to verify_url unless idv_attempter.exceeded?
  end

  private

  def active_profile?
    current_user.active_profile.present?
  end
end
