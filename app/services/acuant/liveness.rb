module Acuant
  class Liveness < AcuantBase
    # @return [Array(Boolean, Hash)] a tuple of (overall success, error hash)
    def call(image)
      base64_image = Base64.strict_encode64(image)
      live_face_image = selfie_live?(base64_image)
      return failure unless live_face_image

      face_image_from_document = fetch_face_from_document
      return failure unless face_image_from_document

      selfie_face_matches_document?(face_image_from_document, base64_selfie) ? success : failure
    end

    private

    attr_accessor :results

    def failure
      [false, results]
    end

    def success
      [true, nil]
    end

    def selfie_live?(image)
      @results = wrap_network_errors { liveness_service.liveness(image) }
      liveness_result_returns_live?
    end

    def fetch_face_from_document
      data = wrap_network_errors { assure_id.face_image }
      return if data.nil?
      Base64.strict_encode64(data)
    end

    def selfie_face_matches_document?(img1, img2)
      @results = wrap_network_errors { facematch_service.facematch(facematch_body(img1, img2)) }
      facematch_pass?
    end

    def facematch_pass?
      results&.dig('IsMatch')
    end

    def liveness_result_returns_live?
      results&.dig('LivenessResult', 'LivenessAssessment') == 'Live'
    end

    def facematch_body(image1, image2)
      { 'Data':
            { 'ImageOne': image1,
              'ImageTwo': image2 },
        'Settings':
            { 'SubscriptionId': Figaro.env.acuant_assure_id_subscription_id } }.to_json
    end

    def liveness_service
      (simulator_or_env_test? ? Idv::Acuant::FakeLiveness : Idv::Acuant::Liveness).new
    end

    def facematch_service
      (simulator_or_env_test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::FacialMatch).new
    end

    def simulator_or_env_test?
      Rails.env.test? || Figaro.env.acuant_simulator == 'true'
    end
  end
end
