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

    def wrap_network_errors
      request_successful, data = yield
      data = parse_if_json(data)
      return data if request_successful
      render json: {}, status: :service_unavailable
      nil
    end

    def parse_if_json(data)
      JSON.parse(data)
    rescue JSON::ParserError
      data
    end

    def attempter_increment
      Throttler::Increment.call(*idv_throttle_params)
    end

    def attempter_throttled?
      Throttler::IsThrottled.call(*idv_throttle_params)
    end
  end
end
