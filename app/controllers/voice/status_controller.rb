module Voice
  class StatusController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      analytics.track_event(
        Analytics::OTP_VOICE_STATUS,
        call_id: params[:CallSid],
        call_status: params[:CallStatus],
        api_version: params[:ApiVersion],
        direction: params[:Direction],
        to_city: params[:ToCity],
        to_state: params[:ToState],
        to_zip: params[:ToZip],
        to_country: params[:ToCountry],
        duration: params[:CallDuration].to_f
      )

      render nothing: true
    end
  end
end
