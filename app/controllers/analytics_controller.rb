class AnalyticsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :confirm_two_factor_authenticated

  def create
    results.each do |event, result|
      next if result.nil?

      analytics.track_event(event, result.to_h)
    end
    head :ok
  end

  private

  def results
    {
      Analytics::PLATFORM_AUTHENTICATOR => platform_authenticator_result,
    }
  end

  def platform_authenticator_result
    return if platform_authenticator_results_saved? || !platform_authenticator_params_valid?

    session[:platform_authenticator_analytics_saved] = true
    platform_authenticator_available = params[:available] ||
                                       params.dig(:platform_authenticator, :available)
    extra = { platform_authenticator: (platform_authenticator_available == 'true') }
    FormResponse.new(success: true, errors: {}, extra: extra)
  end

  def platform_authenticator_params_valid?
    result = params[:available] || params.dig(:platform_authenticator, :available)
    %w[true false].include?(result)
  end

  def platform_authenticator_results_saved?
    session[:platform_authenticator_analytics_saved] == true ||
      session[:platform_authenticator] == true
  end
end
