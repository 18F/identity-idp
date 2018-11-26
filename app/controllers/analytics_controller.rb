class AnalyticsController < ApplicationController
  skip_before_action :verify_authenticity_token

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
      Analytics::FRONTEND_BROWSER_CAPABILITIES => platform_authenticator_result,
    }
  end

  def platform_authenticator_result
    return unless current_user
    return if platform_authenticator_results_saved? || platform_authenticator_available?.nil?

    session[:platform_authenticator_analytics_saved] = true
    extra = { platform_authenticator: platform_authenticator_available? }
    FormResponse.new(success: true, errors: {}, extra: extra)
  end

  def platform_authenticator_available?
    @platform_authenticator_available ||= begin
      available = params.dig(:platform_authenticator, :available)
      available == 'true' if %w[true false].include?(available)
    end
  end

  def platform_authenticator_results_saved?
    session[:platform_authenticator_analytics_saved] == true
  end
end
