module AcuantMock
  class AcuantMockClient
    class << self
      attr_reader :response_mocks
    end

    def self.mock_response!(method:, response:)
      @response_mocks ||= {}
      @response_mocks[method.to_sym] = response
    end

    def self.reset_mocked_responses!
      @response_mocks = {}
    end

    def create_document
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      instance_id = SecureRandom.uuid
      Responses::CreateDocumentResponse.new(success: true, errors: [], instance_id: instance_id)
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def post_front_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      Acuant::Response.new(success: true)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # rubocop:disable Lint/UnusedMethodArgument
    def post_back_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.last_uploaded_back_image = image
      Acuant::Response.new(success: true)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # rubocop:disable Lint/UnusedMethodArgument
    def get_results(instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      ResultResponseBuilder.new(last_uploaded_back_image).call
    end
    # rubocop:enable Lint/UnusedMethodArgument

    private

    attr_accessor :last_uploaded_back_image

    def method_mocked?(method_name)
      mocked_response_for_method(method_name).present?
    end

    def mocked_response_for_method(method_name)
      return if self.class.response_mocks.nil?

      self.class.response_mocks[method_name.to_sym]
    end
  end
end
