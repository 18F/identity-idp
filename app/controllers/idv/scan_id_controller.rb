# rubocop:disable Metrics/ClassLength
module Idv
  class ScanIdController < ApplicationController
    before_action :ensure_user_not_throttled, only: [:new]
    before_action :ensure_fully_authenticated_user_or_token

    ACUANT_PASS = 1
    SUBSCRIPTION_DATA = [{
      'DocumentProcessMode': 2,
      'Id': Figaro.env.acuant_assure_id_subscription_id,
      'IsActive': true,
      'IsDevelopment': Rails.env.development?,
      'IsTrial': false,
      'Name': '',
      'StorePII': false,
    }].freeze
    CLASSIFICATION_DATA = {
      'Type': {
      },
    }.freeze
    USER_SESSION_FLOW_ID = 'idv/doc_auth_v2'.freeze

    def new
      SecureHeaders.append_content_security_policy_directives(request,
                                                              script_src: ['\'unsafe-eval\''])
      render layout: false
    end

    def scan_complete
      if all_checks_passed?
        token_user_id ? continue_to_ssn_on_desktop : continue_to_ssn
      else
        idv_failure
      end
      clear_scan_id_session
    end

    def subscriptions
      render_json SUBSCRIPTION_DATA
    end

    def instance
      session[:scan_id] = {}
      render_json(proxy_request { assure_id.create_document })
    end

    def image
      assure_id.instance_id = params[:instance_id]
      result = assure_id.post_image(request.body.read, params[:side].to_i)
      render_json result
    end

    def classification
      # use service when we accept multiple document types and dynamically decide # of sides
      render_json CLASSIFICATION_DATA
    end

    def document
      instance_id = params[:instance_id]
      assure_id.instance_id = instance_id
      data = proxy_request { assure_id.document }
      return unless data
      render_json process_data_and_store_pii_in_session_if_document_passes(data, instance_id)
    end

    def field_image
      render_json({})
    end

    def liveness
      live_face_image = process_selfie
      return unless live_face_image
      scan_id_session[:liveness_pass] = true

      face_image_from_document = fetch_face_from_document
      return unless face_image_from_document

      check_face_match(face_image_from_document, live_face_image)
      render_json({})
    end

    def facematch
      render_json({})
    end

    private

    def check_face_match(image1, image2)
      data = proxy_request { facematch_service.facematch(facematch_body(image1, image2)) }
      return unless data
      scan_id_session[:facematch_pass] = facematch_pass?(data)
    end

    def facematch_body(image1, image2)
      { 'Data':
        { 'ImageOne': image1,
          'ImageTwo': image2 },
        'Settings':
          { 'SubscriptionId': Figaro.env.acuant_assure_id_subscription_id } }.to_json
    end

    def fetch_face_from_document
      assure_id.instance_id = scan_id_session[:instance_id]
      data = proxy_request { assure_id.face_image }
      return if data.blank?
      Base64.strict_encode64(data)
    end

    def process_selfie
      liveness_body = request.body.read
      liveness_data = proxy_request { liveness_service.liveness(liveness_body) }
      return unless liveness_data
      unless selfie_live?(liveness_data)
        render_json({})
        return
      end
      JSON.parse(liveness_body)['Image']
    end

    def process_data_and_store_pii_in_session_if_document_passes(data, instance_id)
      data = JSON.parse(data)
      if data['Result'] == ACUANT_PASS
        scan_id_session[:instance_id] = instance_id
        scan_id_session[:pii] =
          Idv::Utils::PiiFromDoc.new(data).call(current_user&.phone_configurations&.take&.phone)
      end
      data
    end

    def facematch_pass?(data)
      JSON.parse(data)['IsMatch']
    end

    def selfie_live?(data)
      JSON.parse(data)['LivenessResult']['LivenessAssessment'] == 'Live'
    end

    def flow_session
      user_session[USER_SESSION_FLOW_ID]
    end

    def assure_id
      @assure_id ||= new_assure_id
    end

    def new_assure_id
      (Rails.env.test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId).new
    end

    def liveness_service
      (Rails.env.test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::Liveness).new
    end

    def facematch_service
      (Rails.env.test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::FacialMatch).new
    end

    def ensure_fully_authenticated_user_or_token
      return if user_signed_in? && user_fully_authenticated?
      ensure_user_id_in_session
    end

    def ensure_user_id_in_session
      return if token_user_id && token.blank?
      result = CaptureDoc::ValidateRequestToken.new(token).call
      analytics.track_event(Analytics::DOC_AUTH, result.to_h)
      process_result(result)
    end

    def process_result(result)
      if result.success?
        reset_session
        session[:token_user_id] = result.extra[:for_user_id]
      else
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end
    end

    def all_checks_passed?
      scan_id_session && scan_id_session[:instance_id] && scan_id_session[:liveness_pass] &&
        scan_id_session[:facematch_pass]
    end

    def token
      params[:token]
    end

    def render_json(data)
      return if data.nil?
      render json: data
    end

    def proxy_request
      request_successful, data = yield
      return data if request_successful
      render json: {}, status: :service_unavailable
      nil
    end

    def continue_to_ssn_on_desktop
      CaptureDoc::UpdateAcuantToken.call(token_user_id,
                                         scan_id_session[:instance_id])
      render :capture_complete
    end

    def continue_to_ssn
      flow_session[:pii_from_doc] = scan_id_session[:pii]
      flow_session[:pii_from_doc]['uuid'] = current_user.uuid
      user_session[USER_SESSION_FLOW_ID]['Idv::Steps::ScanIdStep'] = true
      redirect_to idv_doc_auth_v2_step_url(step: :ssn)
    end

    def scan_id_session
      session[:scan_id]
    end

    def clear_scan_id_session
      session.delete(:scan_id)
      session.delete(:token_user_id)
    end

    def ensure_user_not_throttled
      redirect_to idv_session_errors_throttled_url if attempter_throttled?
    end

    def current_user_id
      token_user_id || current_user.id
    end

    def token_user_id
      session[:token_user_id]
    end

    def idv_failure
      attempter_increment
      if attempter_throttled?
        redirect_to idv_session_errors_throttled_url
      else
        redirect_to idv_session_errors_warning_url
      end
    end

    def idv_throttle_params
      [current_user_id, :idv_resolution]
    end

    def attempter_increment
      Throttler::Increment.call(*idv_throttle_params)
    end

    def attempter_throttled?
      Throttler::IsThrottled.call(*idv_throttle_params)
    end
  end
end
# rubocop:enable Metrics/ClassLength
