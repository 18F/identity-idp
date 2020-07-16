# rubocop:disable Lint/UnusedMethodArgument
module DocAuthMock
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
      Responses::CreateDocumentResponse.new(success: true, errors: [], instance_id: instance_id)
    end

    def post_front_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.class.last_uploaded_front_image = image
      Acuant::Response.new(success: true)
    end

    def post_back_image(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.class.last_uploaded_back_image = image
      Acuant::Response.new(success: true)
    end

    def post_selfie(image:, instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      self.class.last_uploaded_selfie_image = image
      Acuant::Response.new(success: true)
    end

    # rubocop:disable Metrics/AbcSize
    def post_images(front_image:, back_image:, selfie_image:, instance_id: nil)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      document = create_document
      return document unless document.success?

      instance_id ||= create_document.instance_id
      front_response = post_front_image(image: front_image, instance_id: instance_id)
      back_response = post_back_image(image: back_image, instance_id: instance_id)
      response = merge_post_responses(front_response, back_response)
      results = check_results(response, instance_id)
      if results.success?
        pii = results.pii_from_doc
        selfie_response = post_selfie(image: selfie_image, instance_id: instance_id)
        [selfie_response, pii]
      else
        results
      end
    end
    # rubocop:enable Metrics/AbcSize

    def get_results(instance_id:)
      return mocked_response_for_method(__method__) if method_mocked?(__method__)

      ResultResponseBuilder.new(self.class.last_uploaded_back_image).call
    end

    private

    def method_mocked?(method_name)
      mocked_response_for_method(method_name).present?
    end

    def mocked_response_for_method(method_name)
      return if self.class.response_mocks.nil?

      self.class.response_mocks[method_name.to_sym]
    end

    def check_results(post_response, instance_id)
      if post_response.success?
        fetch_doc_auth_results(instance_id)
      else
        failure(post_response.errors.first, post_response.to_h)
      end
    end

    def fetch_doc_auth_results(instance_id)
      results_response = get_results(instance_id: instance_id)
      handle_document_verification_failure(results_response) unless results_response.success?

      results_response
    end

    def handle_document_verification_failure(get_results_response)
      mark_step_incomplete(:front_image)
      extra = get_results_response.to_h.merge(
        notice: I18n.t('errors.doc_auth.general_info'),
      )
      failure(get_results_response.errors.first, extra)
    end

    def merge_post_responses(front_response, back_response)
      Acuant::Response.new(
        success: front_response.success? && back_response.success?,
        errors: (front_response.errors || []) + (back_response.errors || []),
        exception: front_response.exception || back_response.exception,
        extra: { front_response: front_response, back_response: back_response },
      )
    end

    def failure(message, extra = nil)
      form_response_params = { success: false, errors: { message: message } }
      if extra.present?
        form_response_params[:extra] = extra unless extra.nil?
      end
      FormResponse.new(form_response_params)
    end
  end
end
# rubocop:enable Lint/UnusedMethodArgument
