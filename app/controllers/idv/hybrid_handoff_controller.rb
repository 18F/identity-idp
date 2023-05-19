module Idv
  class HybridHandoffController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :render_404_if_hybrid_handoff_controller_disabled
    before_action :confirm_agreement_step_complete

    def show
      analytics.idv_doc_auth_upload_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'upload', :view,
        true
      )

      render :show, locals: extra_view_variables
    end

    def update
      irs_attempts_api_tracker.idv_document_upload_method_selected(
        upload_method: params[:type],
      )

      # See the simple_form_for in
      # app/views/idv/doc_auth/upload.html.erb
      if hybrid_flow_chosen?
        handle_phone_submission
      else
        bypass_send_link_steps
      end
    end

    def hybrid_flow_chosen?
      params[:type] != 'desktop' && !mobile_device?
    end

    def handle_phone_submission
      throttle.increment!
      return throttled_failure if throttle.throttled?
      idv_session[:phone_for_mobile_flow] = permit(:phone)[:phone]
      flow_session[:phone_for_mobile_flow] = idv_session[:phone_for_mobile_flow]
      telephony_result = send_link
      failure_reason = nil
      if !telephony_result.success?
        failure_reason = { telephony: [telephony_result.error.class.name.demodulize] }
      end
      irs_attempts_api_tracker.idv_phone_upload_link_sent(
        success: telephony_result.success?,
        phone_number: formatted_destination_phone,
        failure_reason: failure_reason,
      )

      if IdentityConfig.store.doc_auth_link_sent_controller_enabled
        flow_session[:flow_path] = 'hybrid'
        redirect_to idv_link_sent_url
      end

      build_telephony_form_response(telephony_result)
    end

    def bypass_send_link_steps
      mark_upload_step_complete
      mark_link_sent_step_complete

      #flow_session[:flow_path] = @flow.flow_path
      redirect_to idv_document_capture_url

      response = form_response(destination: :document_capture)
      analytics.idv_doc_auth_upload_submitted(
        **analytics_arguments.merge(response.to_h),
      )
      response
    end

    def mark_link_sent_step_complete
      flow_session['Idv::Steps::LinkSentStep'] = true
    end

    def mark_upload_step_complete
      flow_session['Idv::Steps::UploadStep'] = true
    end

    def extra_view_variables
      {
        flow_session: flow_session,
        idv_phone_form: build_form,
      }
    end

    def form_response(destination:)
      FormResponse.new(
        success: true,
        errors: {},
        extra: {
          destination: destination,
          skip_upload_step: mobile_device?,
        },
      )
    end

    def mobile_device?
      # See app/javascript/packs/document-capture-welcome.js
      # And app/services/idv/steps/agreement_step.rb
      !!flow_session[:skip_upload_step]
    end

    def build_form
      Idv::PhoneForm.new(
        previous_params: {},
        user: current_user,
        delivery_methods: [:sms],
      )
    end

    def render_404_if_hybrid_handoff_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled
    end

    def confirm_agreement_step_complete
      return if flow_session['Idv::Steps::AgreementStep']

      redirect_to idv_doc_auth_url
    end

    def analytics_arguments
      {
        step: 'upload',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end
  end
end
