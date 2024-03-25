# frozen_string_literal: true

module DocAuth
  module Mock
    class TrueIdMockClient < DocAuth::Mock::DocAuthMockClient
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
      end

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
        http_response_builder.use_uploaded_file(back_image)
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
      def self.mock_response!(method:, response:)
        @response_mocks ||= {}
        @response_mocks[method.to_sym] = response
      end

      def self.reset!
        @response_mocks = {}
        @last_uploaded_front_image = nil
        @last_uploaded_back_image = nil
      end

      def method_mocked?(method_name)
        mocked_response_for_method(method_name).present?
      end

      def mocked_response_for_method(method_name)
        return if self.class.response_mocks.nil?

        self.class.response_mocks[method_name.to_sym]
      end
    end
  end
end
