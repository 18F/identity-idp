# rubocop:disable Metrics/ClassLength
# rubocop:disable Style/ColonMethodCall
module Idv
  module Steps
    class DocAuthBaseStep < Flow::BaseStep
      GOOD_RESULT = 1
      FYI_RESULT = 2

      def initialize(flow)
        @assure_id = nil
        @pii_from_test_doc = nil
        super(flow, :doc_auth)
      end

      private

      def image
        uploaded_image = flow_params[:image]
        return uploaded_image if uploaded_image.present?
        DataUrlImage.new(flow_params[:image_data_url])
      end

      def assure_id
        @assure_id ||= new_assure_id
        @assure_id.instance_id = flow_session[:instance_id] if flow_session[:instance_id]
        @assure_id
      end

      def new_assure_id
        klass = simulate? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId
        klass.new
      end

      def simulate?
        Figaro.env.acuant_simulator == 'true'
      end

      def idv_throttle_params
        [current_user.id, :idv_resolution]
      end

      def attempter_increment
        Throttler::Increment.call(*idv_throttle_params)
      end

      def attempter_throttled?
        Throttler::IsThrottled.call(*idv_throttle_params)
      end

      def idv_failure(result)
        attempter_increment
        if attempter_throttled?
          redirect_to idv_session_errors_failure_url
        else
          redirect_to idv_session_errors_warning_url
        end
        result
      end

      def verify_back_image(reset_step:)
        back_image_verified, data, analytics_hash = assure_id_results
        data[:notice] = I18n.t('errors.doc_auth.general_info') if data.class == Hash
        return friendly_failure(data, analytics_hash) unless back_image_verified

        return [nil, data] if process_good_result(data)

        mark_step_incomplete(reset_step)
        friendly_failure(I18n.t('errors.doc_auth.general_error'), data)
      end

      def process_good_result(data)
        return unless data['Result'] == GOOD_RESULT
        save_proofing_components
        true
      end

      def save_proofing_components
        Db::ProofingComponent::Add.call(user_id, :document_check, 'acuant')
        Db::ProofingComponent::Add.call(user_id, :document_type, 'state_id')
        return unless liveness_checking_enabled?
        Db::ProofingComponent::Add.call(user_id, :liveness_check, 'acuant')
      end

      def extract_pii_from_doc(data)
        flow_session[:pii_from_doc] = test_credentials? ? pii_from_test_doc : parse_pii(data)
        flow_session[:pii_from_doc]['uuid'] = current_user.uuid
      end

      def pii_from_test_doc
        @pii_from_test_doc ||= YAML.safe_load(image.read)&.[]('document')&.symbolize_keys || {}
      end

      def parse_pii(data)
        Idv::Utils::PiiFromDoc.new(data).call(current_user&.phone_configurations&.take&.phone)
      end

      def user_id_from_token
        flow_session[:doc_capture_user_id]
      end

      def assure_id_results
        return assure_id_test_results if test_credentials?
        rescue_network_errors { assure_id.results }
      end

      def assure_id_test_results
        friendly_error = pii_from_test_doc&.[](:friendly_error)
        if friendly_error
          msg = I18n.t("friendly_errors.doc_auth.#{friendly_error}")
          return [false, msg] if msg
        end
        [true, { 'Result' => GOOD_RESULT }]
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
        return throttled if throttled_else_increment
        rescue_network_errors do
          result = assure_id.post_front_image(image.read)
          add_cost(:acuant_front_image)
          result
        end
      end

      def throttle_post_back_image
        return throttled if throttled_else_increment
        rescue_network_errors do
          result = assure_id.post_back_image(image.read)
          add_cost(:acuant_back_image)
          result
        end
      end

      def throttled
        redirect_to throttled_url
        [false, I18n.t('errors.doc_auth.acuant_throttle')]
      end

      def throttled_url
        return idv_session_errors_throttled_url unless @flow.class == Idv::Flows::RecoveryFlow
        idv_session_errors_recovery_throttled_url
      end

      def test_credentials?
        return false unless flow_params
        FeatureManagement.allow_doc_auth_test_credentials? &&
          ['application/x-yaml', 'text/x-yaml', 'text/plain'].include?(image.content_type)
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_acuant)
      end

      def user_id
        current_user ? current_user.id : user_id_from_token
      end

      def rescue_network_errors
        Timeout::timeout(acuant_timeout) { yield }
      rescue Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed => exception
        NewRelic::Agent.notice_error(exception)
        [
          false,
          I18n.t('errors.doc_auth.acuant_network_error'),
          { acuant_network_error: exception.message },
        ]
      end

      def acuant_timeout
        Figaro.env.acuant_timeout.to_i
      end

      def friendly_failure(message, data)
        acuant_alert = friendly_acuant_alert(data)
        message = acuant_alert if acuant_alert.present?
        new_message = friendly_message(message)
        failure(new_message, friendly_failure_extra(data))
      end

      def friendly_failure_extra(data)
        return data if data.is_a? String
        data&.slice('Alerts', :notice)
      end

      def friendly_acuant_alert(data)
        acuant_alert = data&.dig('Alerts')&.first&.dig('Disposition')
        return acuant_alert if friendly_message(acuant_alert) != acuant_alert
        nil
      end

      def add_cost(token)
        issuer = sp_session[:issuer].to_s
        Db::SpCost::AddSpCost.call(issuer, 2, token)
        Db::ProofingCost::AddUserProofingCost.call(user_id, token)
      end

      def friendly_message(message)
        FriendlyError::Message.call(message, 'doc_auth')
      end

      def sp_session
        session.fetch(:sp, {})
      end

      def mark_selfie_step_complete_unless_liveness_checking_is_enabled
        mark_step_complete(:selfie) unless liveness_checking_enabled?
      end

      def liveness_checking_enabled?
        FeatureManagement.liveness_checking_enabled? && (no_sp? || sp_liveness_checking_required?)
      end

      def sp_liveness_checking_required?
        ServiceProvider.from_issuer(sp_session[:issuer].to_s)&.liveness_checking_required
      end

      def no_sp?
        sp_session[:issuer].blank?
      end

      delegate :idv_session, :session, to: :@flow
    end
  end
end
# rubocop:enable Style/ColonMethodCall
# rubocop:enable Metrics/ClassLength
