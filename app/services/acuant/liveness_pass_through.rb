module Acuant
  class LivenessPassThrough < AcuantBase
    # @return [is_photo_live?, does_face_in_photo_match_license_face?]
    def call(liveness_body)
      live_face_image = process_selfie(liveness_body)
      return unless live_face_image

      face_image_from_document = fetch_face_from_document
      return [true, false] unless face_image_from_document

      [true, check_face_match(face_image_from_document, live_face_image)]
    end

    private

    def process_selfie(liveness_body)
      liveness_data = wrap_network_errors { liveness_service.liveness(liveness_body) }
      return unless liveness_data
      return unless selfie_live?(liveness_data)
      JSON.parse(liveness_body)['Image']
    end

    def fetch_face_from_document
      data = wrap_network_errors { assure_id.face_image }
      return if data.nil?
      Base64.strict_encode64(data)
    end

    def check_face_match(image1, image2)
      data = wrap_network_errors { facematch_service.facematch(facematch_body(image1, image2)) }
      return unless data
      facematch_pass?(data)
    end

    def facematch_pass?(data)
      data['IsMatch']
    end

    def selfie_live?(data)
      data['LivenessResult']['LivenessAssessment'] == 'Live'
    end

    def facematch_body(image1, image2)
      { 'Data':
            { 'ImageOne': image1,
              'ImageTwo': image2 },
        'Settings':
            { 'SubscriptionId': Figaro.env.acuant_assure_id_subscription_id } }.to_json
    end

    def liveness_service
      (simulator_or_env_test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::Liveness).new
    end

    def facematch_service
      (simulator_or_env_test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::FacialMatch).new
    end

    def simulator_or_env_test?
      Rails.env.test? || Figaro.env.acuant_simulator == 'true'
    end
  end
end
