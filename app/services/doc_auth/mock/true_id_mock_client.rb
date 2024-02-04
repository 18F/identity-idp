# frozen_string_literal: true

module DocAuth
  module Mock
    class TrueIdMockClient < DocAuth::Mock::DocAuthMockClient
      # rubocop:disable Lint/UnusedMethodArgument
      def post_images(
        front_image:,
        back_image: nil,
        selfie_image: nil,
        image_source: nil,
        user_uuid: nil,
        uuid_prefix: nil,
        liveness_checking_required: false
      )
        if respond_to?(:method_mocked?, true)
          return mocked_response_for_method(__method__) if method_mocked?(__method__)
        end
        http_response_builder = TrueIdHttpResponseBuilder.new(
          templatefile: 'true_id_response_success_with_liveness.json',
          selfie_check_enabled: liveness_checking_required,
        )
        http_response_builder.set_check_status('2D Barcode Read', 'Passed')
        http_response_builder.use_uploaded_file(front_image)
        response_body = http_response_builder.build
        stubs = Faraday::Adapter::Test::Stubs.new(strict_mode: false)
        # Instantiate a connection that uses the test adapter
        conn = Faraday.new { |b| b.adapter(:test, stubs) }
        stubs.post('/dummy') do
          [
            200,
            { 'Content-Type': 'application/json' },
            response_body,
          ]
        end
        response = conn.post('/dummy')
        DocAuth::LexisNexis::Responses::TrueIdResponse.new(
          response, config,
          liveness_checking_required
        )
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
