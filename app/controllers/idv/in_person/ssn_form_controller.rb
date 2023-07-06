module Idv
  module InPerson
    class SsnFormController < ApplicationController
      include IdvStepConcern
      include StepIndicatorConcern
      include StepUtilitiesConcern
      include Steps::ThreatMetrixStepHelper
      include ThreatMetrixConcern

      before_action :renders_404_if_flag_not_set
      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_address_step_complete
      before_action :confirm_repeat_ssn, only: :show
      # before_action :confirm_in_person_verify_info_step_needed
      # TO DO: CONFIRM PRIOR STEP IS COMPLETE (CHECK THAT PII FROM USER IS THERE)
      # before_action :confirm_document_capture_complete


      attr_accessor :error_message

      def show
          @in_person_proofing = true
          @step_indicator_steps = step_indicator_steps
          @ssn_form = Idv::SsnFormatForm.new(current_user, flow_session)

          increment_step_counts

          analytics.idv_doc_auth_redo_ssn_submitted(**analytics_arguments) if updating_ssn?
          analytics.idv_doc_auth_ssn_visited(**analytics_arguments)

          Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('ssn', :view, true)

          render :show, locals: extra_view_variables
      end

      def update
          @error_message = nil

          @ssn_form = Idv::SsnFormatForm.new(current_user, flow_session)
          form_response = @ssn_form.submit(permit(:ssn))

          analytics.idv_doc_auth_ssn_submitted(
          **analytics_arguments.merge(form_response.to_h),
          )
          irs_attempts_api_tracker.idv_ssn_submitted(
          ssn: params[:doc_auth][:ssn],
          )


          if form_response.success?
            flow_session['pii_from_user'][:ssn] = params[:doc_auth][:ssn]

            idv_session.invalidate_steps_after_ssn!
            redirect_to next_url
          else
            @error_message = form_response.first_error_message
            render :show, locals: threatmetrix_view_variables
          end
      end

      ##
      # In order to test the behavior without the threatmetrix JS, we do not load the threatmetrix
      # JS if the user's email is on a list of JS disabled emails.
      #
      def should_render_threatmetrix_js?
          return false unless FeatureManagement.proofing_device_profiling_collecting_enabled?

          current_user.email_addresses.each do |email_address|
          no_csp_email = IdentityConfig.store.idv_tmx_test_js_disabled_emails.include?(
              email_address.email,
          )
          return false if no_csp_email
          end

          true
      end

      def extra_view_variables
        {
          updating_ssn: updating_ssn?,
          **threatmetrix_view_variables,
        }
      end

      private

      def current_flow_step_counts
        user_session['idv/in_person_flow_step_counts'] ||= {}
        user_session['idv/in_person_flow_step_counts'].default = 0
        user_session['idv/in_person_flow_step_counts']
      end

      def flow_session
        user_session.fetch('idv/in_person', {})
      end

      def flow_path
        flow_session[:flow_path]
      end

      def increment_step_counts
        current_flow_step_counts['Idv::Steps::SsnStep'] += 1
      end

      def permit(*args)
        params.require(:doc_auth).permit(*args)
      end


       # TO DO: Why is this step needed? only for idv, not idv_in_person?
      def confirm_repeat_ssn
        # return if !pii_from_user[:ssn]
        # return if request.referer == idv_in_person_verify_info_url

        # redirect_to idv_in_person_verify_info_url
      end

      def next_url
        idv_in_person_verify_info_url
      end

      def analytics_arguments
          {
          flow_path: flow_path,
          step: 'ssn',
          step_count: current_flow_step_counts['Idv::Steps::SsnStep'],
          analytics_id: 'In Person Proofing',
          irs_reproofing: irs_reproofing?,
          }.merge(**acuant_sdk_ab_test_analytics_args)
      end

      def updating_ssn?
        flow_session.dig(:pii_from_user, :ssn).present?
      end

      def renders_404_if_flag_not_set
        render_not_found unless IdentityConfig.store.in_person_ssn_info_controller_enabled
      end

      # def pii_from_user
      #   flow_session[:pii_from_user]
      # end
    end
  end
end
  