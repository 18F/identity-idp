module Idv
  class ScanIdAcuantController < ScanIdBaseController
    before_action :ensure_fully_authenticated_user_or_token_user_id
    before_action :return_good_document_if_throttled_else_increment, only: [:document]
    before_action :return_if_liveness_disabled, only: [:liveness]
    before_action :return_if_throttled_else_increment, only: [:liveness]

    GOOD_DOCUMENT = { 'Result': 1, 'Fields': [{}] }.freeze
    USER_SESSION_FLOW_ID = 'idv/doc_auth_v2'.freeze

    def subscriptions
      render_json ::Acuant::Subscriptions.new.call
    end

    def instance
      session[:scan_id] = {}
      render_json ::Acuant::Instance.new.call
    end

    def image
      render_json ::Acuant::Image.new(params[:instance_id]).
                    call(request.body.read, params[:side])
    end

    def classification
      render_json ::Acuant::Classification.new.call
    end

    def document
      data, instance_id, pii = ::Acuant::Document.new(params[:instance_id]).call(current_user)
      if pii
        scan_id_session[:instance_id] = instance_id
        scan_id_session[:pii] = pii
      end
      render_json data
    end

    def field_image
      render_json({})
    end

    def liveness
      is_live, is_face_match = ::Acuant::Liveness.
                               new(scan_id_session[:instance_id]).call(request.body.read)
      scan_id_session[:liveness_pass] = is_live
      scan_id_session[:facematch_pass] = is_face_match
      render_json({})
    end

    def facematch
      render_json({})
    end

    private

    def return_good_document_if_throttled_else_increment
      render_json(GOOD_DOCUMENT) if Throttler::IsThrottledElseIncrement.call(*idv_throttle_params)
    end

    def return_if_throttled_else_increment
      render_json({}) if Throttler::IsThrottledElseIncrement.call(*idv_throttle_params)
    end

    def return_if_liveness_disabled
      render_json({}) unless FeatureManagement.liveness_checking_enabled?
    end

    def ensure_fully_authenticated_user_or_token_user_id
      return if token_user_id || (user_signed_in? && user_fully_authenticated?)
      render json: {}, status: :unauthorized
    end
  end
end
