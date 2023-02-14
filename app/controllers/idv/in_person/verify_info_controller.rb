module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
      include IdvSession

      before_action :renders_404_if_flag_not_set
      before_action :confirm_two_factor_authenticated
      before_action :confirm_ssn_step_complete
      before_action :confirm_profile_not_already_confirmed

      def show
        @in_person_proofing = true
        @which_verify_controller = idv_in_person_verify_info_path

        increment_step_counts
        analytics.idv_doc_auth_verify_visited(**analytics_arguments)
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('verify', :view, true) # specify in_person?

        render 'idv/verify_info/show'
      end

      private

      def renders_404_if_flag_not_set
        unless IdentityConfig.store.doc_auth_in_person_verify_info_controller_enabled
          render_not_found
        end
      end

      ##### Move to VerifyInfoConcern

      # copied from address_controller
      def confirm_ssn_step_complete
        return if pii.present? && pii[:ssn].present?
        redirect_to idv_doc_auth_url
      end

      def confirm_profile_not_already_confirmed
        return unless idv_session.profile_confirmation == true
        redirect_to idv_review_url
      end

      def pii
        @pii = flow_session[:pii_from_doc] if flow_session
      end

      def current_flow_step_counts
        user_session['idv/doc_auth_flow_step_counts'] ||= {}
        user_session['idv/doc_auth_flow_step_counts'].default = 0
        user_session['idv/doc_auth_flow_step_counts']
      end

      def increment_step_counts
        current_flow_step_counts['verify'] += 1
      end

      # copied from doc_auth_controller
      def flow_session
        user_session['idv/doc_auth']
      end

      def flow_path
        flow_session[:flow_path]
      end

      def irs_reproofing?
        effective_user&.decorate&.reproof_for_irs?(
          service_provider: current_sp,
        ).present?
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'verify',
          step_count: current_flow_step_counts['verify'],
          analytics_id: 'Doc Auth',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end

      # Copied from capture_doc_flow.rb
      # and from doc_auth_flow.rb
      def acuant_sdk_ab_test_analytics_args
        capture_session_uuid = flow_session[:document_capture_session_uuid]
        if capture_session_uuid
          {
            acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(capture_session_uuid),
          }
        else
          {}
        end
      end
    end
  end
end
