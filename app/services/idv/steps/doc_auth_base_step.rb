# :reek:TooManyMethods
# :reek:RepeatedConditional
# rubocop:disable Metrics/ClassLength
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
        back_image_verified, data, analytics_hash = assure_id_results
        data[:notice] = I18n.t('errors.doc_auth.general_info')
        return failure(data, analytics_hash) unless back_image_verified

        return [nil, data] if data['Result'] == GOOD_RESULT

        mark_step_incomplete(reset_step)
        failure(I18n.t('errors.doc_auth.general_error'), data)
      end

      def extract_pii_from_doc(data)
        flow_session[:pii_from_doc] = test_credentials? ? pii_from_test_doc : parse_pii(data)
        flow_session[:pii_from_doc]['uuid'] = current_user.uuid
      end

      def pii_from_test_doc
        YAML.safe_load(image.read)['document'].symbolize_keys
      end

      def parse_pii(data)
        Idv::Utils::PiiFromDoc.new(data).call(
          current_user&.phone_configurations&.take&.phone,
        )
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def assure_id_results
        return [true, { 'Result' => GOOD_RESULT }] if test_credentials?
        rescue_network_errors { assure_id.results }
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
        return [false, I18n.t('errors.doc_auth.acuant_throttle')] if throttled_else_increment
        rescue_network_errors { assure_id.post_front_image(image.read) }
      end

      def throttle_post_back_image
        return [false, I18n.t('errors.doc_auth.acuant_throttle')] if throttled_else_increment
        rescue_network_errors { assure_id.post_back_image(image.read) }
      end

      def test_credentials?
        return false unless flow_params
        FeatureManagement.allow_doc_auth_test_credentials? &&
          ['text/x-yaml', 'text/plain'].include?(image.content_type)
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_acuant)
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def rescue_network_errors
        yield
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => exception
        NewRelic::Agent.notice_error(exception)
        [
          false,
          I18n.t('errors.doc_auth.acuant_network_error'),
          { acuant_network_error: exception.message },
        ]
      end

      delegate :idv_session, to: :@flow
    end
  end
end
# rubocop:enable Metrics/ClassLength
