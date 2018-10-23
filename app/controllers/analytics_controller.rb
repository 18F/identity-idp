class AnalyticsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :confirm_two_factor_authenticated

  def create
    unless analytics_saved?
      session[:platform_authenticator] = true
      analytics.track_event(Analytics::PLATFORM_AUTHENTICATOR, results.to_h)
    end
    head :ok
  end

  private

  def results
    FormResponse.new(success: true, errors: {},
                     extra: { platform_authenticator: params[:available] })
  end

  def analytics_saved?
    session[:platform_authenticator]
  end
end
