class IdvController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated

  def index
    if current_user.active_profile.present?
      redirect_to idv_activated_url
    else
      analytics.track_event(Analytics::IDV_INTRO_VISIT)
    end
  end

  def cancel
  end

  def fail
  end

  def retry
    flash.now[:error] = I18n.t('idv.errors.fail')
  end

  def activated
  end
end
