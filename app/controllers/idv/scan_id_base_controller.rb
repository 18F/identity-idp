module Idv
  class ScanIdBaseController < ApplicationController
    private

    def scan_id_session
      session[:scan_id]
    end

    def current_user_id
      token_user_id || current_user.id.to_i
    end

    def token_user_id
      session[:token_user_id]
    end

    def idv_throttle_params
      [current_user_id, :idv_acuant]
    end

    def render_json(data)
      return if data.nil?
      render json: data
    end

    def attempter_increment
      Throttler::Increment.call(*idv_throttle_params)
    end

    def attempter_throttled?
      Throttler::IsThrottled.call(*idv_throttle_params)
    end

    def selfie_live_and_matches_document?
      scan_id_session[:facematch_pass] && scan_id_session[:liveness_pass]
    end

    def liveness_checking_enabled?
      FeatureManagement.liveness_checking_enabled? && sp_liveness_checking_enabled?
    end

    def sp_liveness_checking_enabled?
      ServiceProvider.from_issuer(sp_session[:issuer].to_s)&.liveness_checking_enabled
    end
  end
end
