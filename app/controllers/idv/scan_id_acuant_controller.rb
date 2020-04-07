# rubocop:disable Metrics/ClassLength
module Idv
  class ScanIdAcuantController < ScanIdBaseController
    before_action :ensure_fully_authenticated_user_or_token_user_id
    before_action :return_good_document_if_throttled_else_increment, only: [:document]
    before_action :return_if_liveness_disabled, only: [:liveness]
    before_action :return_if_throttled_else_increment, only: [:liveness]

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
    GOOD_DOCUMENT = { 'Result': 1, 'Fields': [{}] }.freeze
    USER_SESSION_FLOW_ID = 'idv/doc_auth_v2'.freeze

    def subscriptions
      render_json SUBSCRIPTION_DATA
    end

    def instance
      session[:scan_id] = {}
      render_json(wrap_network_errors { assure_id.create_document })
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
      data = wrap_network_errors { assure_id.document }
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
      data = wrap_network_errors { facematch_service.facematch(facematch_body(image1, image2)) }
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
      data = wrap_network_errors { assure_id.face_image }
      return if data.nil?
      Base64.strict_encode64(data)
    end

    def process_selfie
      liveness_body = request.body.read
      liveness_data = wrap_network_errors { liveness_service.liveness(liveness_body) }
      return unless liveness_data
      unless selfie_live?(liveness_data)
        render_json({})
        return
      end
      JSON.parse(liveness_body)['Image']
    end

    def process_data_and_store_pii_in_session_if_document_passes(data, instance_id)
      if data['Result'] == ACUANT_PASS
        scan_id_session[:instance_id] = instance_id
        scan_id_session[:pii] =
          Idv::Utils::PiiFromDoc.new(data).call(current_user&.phone_configurations&.take&.phone)
      end
      data
    end

    def facematch_pass?(data)
      data['IsMatch']
    end

    def selfie_live?(data)
      data['LivenessResult']['LivenessAssessment'] == 'Live'
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
# rubocop:enable Metrics/ClassLength
