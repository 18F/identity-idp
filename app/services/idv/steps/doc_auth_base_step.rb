# :reek:TooManyMethods
# :reek:RepeatedConditional

module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      GOOD_RESULT = 1
      FYI_RESULT = 2

      def initialize(flow)
        @assure_id = nil
        super(flow, :doc_auth)
      end

      private

      def image
        flow_params[:image]
      end

      def assure_id
        @assure_id ||= new_assure_id
        @assure_id.instance_id = flow_session[:instance_id]
        @assure_id
      end

      def new_assure_id
        klass = simulate? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId
        klass.new
      end

      def simulate?
        Figaro.env.acuant_simulator == 'true'
      end

      def attempter
        @attempter ||= Idv::Attempter.new(current_user)
      end

      def idv_failure(result)
        attempter.increment
        type = attempter.exceeded? ? :fail : :warning
        redirect_to idv_session_failure_url(reason: type)
        result
      end

      def verify_back_image(reset_step:)
        back_image_verified, data = assure_id_results
        return failure(data) unless back_image_verified

        return [nil, data] if data['Result'] == GOOD_RESULT

        mark_step_incomplete(reset_step)
        failure(I18n.t('errors.doc_auth.general_error'), data)
      end

      def extract_pii_from_doc(data)
        flow_session[:pii_from_doc] = test_credentials? ? pii_from_test_doc : parse_pii(data)
      end

      def pii_from_test_doc
        YAML.safe_load(image.read)['document'].symbolize_keys
      end

      def parse_pii(data)
        Idv::Utils::PiiFromDoc.new(data).call(
          current_user&.phone_configurations&.first&.phone,
        )
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def assure_id_results
        return [true, { 'Result' => GOOD_RESULT }] if test_credentials?
        assure_id.results
      end

      def post_back_image
        return [true, ''] if test_credentials?
        assure_id.post_back_image(image.read)
      end

      def post_front_image
        return [true, ''] if test_credentials?
        assure_id.post_front_image(image.read)
      end

      def test_credentials?
        FeatureManagement.allow_doc_auth_test_credentials? && image.content_type == 'text/x-yaml'
      end

      delegate :idv_session, to: :@flow
    end
  end
end
