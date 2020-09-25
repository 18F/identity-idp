# rubocop:disable Lint/UnusedMethodArgument
module DocAuth
  module Mock
    class DocAuthMockClient
      class << self
        attr_reader :response_mocks
        attr_accessor :last_uploaded_front_image
        attr_accessor :last_uploaded_back_image
        attr_accessor :last_uploaded_selfie_image
      end

      def self.mock_response!(method:, response:)
        @response_mocks ||= {}
        @response_mocks[method.to_sym] = response
      end

      def self.reset!
        @response_mocks = {}
        @last_uploaded_front_image = nil
        @last_uploaded_back_image = nil
        @last_uploaded_selfie_image = nil
      end

      def create_document
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        instance_id = SecureRandom.uuid
        Responses::CreateDocumentResponse.new(success: true, errors: {}, instance_id: instance_id)
      end

      def post_front_image(image:, instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        self.class.last_uploaded_front_image = image
        DocAuth::Response.new(success: true)
      end

      def post_back_image(image:, instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        self.class.last_uploaded_back_image = image
        DocAuth::Response.new(success: true)
      end

      def post_selfie(image:, instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        self.class.last_uploaded_selfie_image = image
        DocAuth::Response.new(success: true)
      end

      def post_images(front_image:, back_image:, selfie_image:, liveness_checking_enabled: nil)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        document_response = create_document
        return document_response unless document_response.success?

        instance_id = document_response.instance_id

        front_image_response = post_front_image(image: front_image, instance_id: instance_id)
        return front_image_response unless front_image_response.success?

        back_image_response = post_back_image(image: back_image, instance_id: instance_id)
        return back_image_response unless back_image_response.success?

        process_results(instance_id, liveness_checking_enabled, selfie_image)
      end

      def get_results(instance_id:)
        return mocked_response_for_method(__method__) if method_mocked?(__method__)

        ResultResponseBuilder.new(self.class.last_uploaded_back_image).call
      end

      private

      def process_results(instance_id, liveness_checking_enabled, selfie_image)
        results_response = get_results(instance_id: instance_id)
        return results_response unless results_response.success?

        if liveness_checking_enabled
          post_selfie(image: selfie_image, instance_id: instance_id).merge(results_response)
        else
          results_response
        end
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
# rubocop:enable Lint/UnusedMethodArgument
