class VerifyController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated

  def index
    if current_user.active_profile.present?
      redirect_to verify_activated_path
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
    end
  end

  def retry
    flash.now[:error] = I18n.t('idv.errors.fail')
  end
end
