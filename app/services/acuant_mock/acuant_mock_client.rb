module AcuantMock
  class AcuantMockClient
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
      Responses::CreateDocumentResponse.new(success: true, errors: [], instance_id: instance_id)
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def post_front_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.class.last_uploaded_front_image = image
      Acuant::Response.new(success: true)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # rubocop:disable Lint/UnusedMethodArgument
    def post_back_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.class.last_uploaded_back_image = image
      Acuant::Response.new(success: true)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    # rubocop:disable Lint/UnusedMethodArgument
    def get_results(instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      ResultResponseBuilder.new(self.class.last_uploaded_back_image).call
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def method_mocked?(method_name)
      mocked_response_for_method(method_name).present?
    end

    def mocked_response_for_method(method_name)
      return if self.class.response_mocks.nil?

      self.class.response_mocks[method_name.to_sym]
    end
  end
end
