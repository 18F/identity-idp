module DocAuth
  module Mock
    class DocAuthMockClient
      include DocAuth::Mock::YmlLoaderConcern
      attr_reader :config

      def initialize(**config_keywords)
        @config = Config.new(**config_keywords)
      end

      class << self
        attr_reader :response_mocks
        attr_accessor :last_uploaded_front_image
        attr_accessor :last_uploaded_back_image
      end

      def self.mock_response!(method:, response:)
        @response_mocks ||= {}
        @response_mocks[method.to_sym] = response
      end

      def self.reset!
        @response_mocks = {}
        @last_uploaded_front_image = nil
        @last_uploaded_back_image = nil
      end

      def create_document
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        instance_id = SecureRandom.uuid
        Responses::CreateDocumentResponse.new(success: true, errors: {}, instance_id: instance_id)
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def post_front_image(image:, instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)
        self.class.last_uploaded_front_image = image
        error_response = http_error_response(image, 'front')
        return error_response if error_response
        DocAuth::Response.new(success: true)
      end

      def post_back_image(image:, instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)
        self.class.last_uploaded_back_image = image
        error_response = http_error_response(image, 'back')
        return error_response if error_response
        DocAuth::Response.new(success: true)
      end

      def post_images(
        front_image:,
        back_image:,
        image_source: nil,
        user_uuid: nil,
        uuid_prefix: nil
      )
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        document_response = create_document
        return document_response unless document_response.success?

        instance_id = document_response.instance_id

        front_image_response = post_front_image(image: front_image, instance_id: instance_id)
        return front_image_response unless front_image_response.success?

        back_image_response = post_back_image(image: back_image, instance_id: instance_id)
        return back_image_response unless back_image_response.success?

        get_results(instance_id: instance_id)
      end

      def get_results(instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)
        error_response = http_error_response(self.class.last_uploaded_back_image, 'result')
        return error_response if error_response
        overriden_config = config.dup.tap do |c|
          c.dpi_threshold = 290
          c.sharpness_threshold = 40
          c.glare_threshold = 40
        end

        ResultResponse.new(
          self.class.last_uploaded_back_image,
          overriden_config,
        )
      end
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def method_mocked?(method_name)
        mocked_response_for_method(method_name).present?
      end

      def mocked_response_for_method(method_name)
        return if self.class.response_mocks.nil?

        self.class.response_mocks[method_name.to_sym]
      end

      def http_error_response(image, side)
        data = parse_yaml(image.to_s)
        status = data.dig('http_status', side)
        return nil unless [500, 440, 438, 439].include?(status)
        errors = case status
                 when 438
                   {
                     general: [Errors::IMAGE_LOAD_FAILURE],
                     side.downcase.to_sym => [Errors::IMAGE_LOAD_FAILURE_FIELD],
                   }
                 when 439
                   {
                     general: [Errors::PIXEL_DEPTH_FAILURE],
                     side.downcase.to_sym => [Errors::PIXEL_DEPTH_FAILURE_FIELD],
                   }
                 when 440
                   {
                     general: [Errors::IMAGE_SIZE_FAILURE],
                     side.downcase.to_sym => [Errors::IMAGE_SIZE_FAILURE_FIELD],
                   }
                 when 500
                   {
                     general: [Errors::NETWORK],
                   }
                 end
        return nil unless errors
        message = [
          self.class.name,
          'Unexpected HTTP response',
          status,
        ].join(' ')
        exception = DocAuth::RequestError.new(message, status)
        DocAuth::Response.new(
          success: false,
          errors: errors,
          exception: exception,
          extra: { vendor: 'Mock' },
        )
      rescue Psych::SyntaxError
        nil
      end
    end
  end
end
