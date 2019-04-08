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
        throttle_post_back_image
      end

      def post_front_image
        return [true, ''] if test_credentials?
        throttle_post_front_image
      end

      def throttle_post_front_image
        return [false, I18n.t('errors.doc_auth.acuant_throttle')] if throttled?
        increment_attempts
        assure_id.post_front_image(image.read)
      end

      def throttle_post_back_image
        return [false, I18n.t('errors.doc_auth.acuant_throttle')] if throttled?
        increment_attempts
        assure_id.post_back_image(image.read)
      end

      def test_credentials?
        return false unless flow_params
        FeatureManagement.allow_doc_auth_test_credentials? &&
          ['text/x-yaml', 'text/plain'].include?(image.content_type)
      end

      def increment_attempts
        Throttler::Increment.new(user_id, :idv_acuant).call
      end

      def throttled?
        Throttler::IsThrottled.new(user_id, :idv_acuant).call(max_attempts, delay_in_minutes)
      end

      def max_attempts
        (Figaro.env.acuant_max_attempts || 3).to_i
      end

      def delay_in_minutes
        (Figaro.env.acuant_attempt_window_in_minutes || 86_400).to_i
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      delegate :idv_session, to: :@flow
    end
  end
end
