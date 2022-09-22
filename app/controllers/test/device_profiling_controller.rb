module Test
  class DeviceProfilingController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    layout false

    # iframe fallback
    def index
      tmx_backend.record_profiling_result(
        session_id: params[:session_id],
        result: 'no_result',
      )
    end

    # explicit JS POST
    def create
      tmx_backend.record_profiling_result(
        session_id: params[:session_id],
        result: params[:result],
      )

      head :ok
    end

    private

    def tmx_backend
      @tmx_backend ||= Proofing::Mock::TmxBackend.new
    end
  end
end
