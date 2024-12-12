# frozen_string_literal: true

module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_identity_verified, if: :identity_proofing_required?
    before_action :apply_secure_headers_override, only: [:show, :update]
    before_action :verify_needs_completions_screen

    def show
      analytics.user_registration_agency_handoff_page_visit(
        **analytics_attributes(''),
      )
      @multiple_factors_enabled = MfaPolicy.new(current_user).multiple_factors_enabled?
      @presenter = completions_presenter
    end

    def update
      track_completion_event('agency-page')
      update_verified_attributes
      send_in_person_completion_survey
      if user_session[:selected_email_id_for_linked_identity].nil?
        user_session[:selected_email_id_for_linked_identity] = EmailContext.new(current_user)
          .last_sign_in_email_address.id
      end
      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to(
          sp_session_request_url_with_updated_params || account_url,
          allow_other_host: true,
        )
      end
    end

    private

    def confirm_identity_verified
      redirect_to idv_url if current_user.identity_not_verified?
    end

    def verify_needs_completions_screen
      return_to_account unless needs_completion_screen_reason
    end

    def completions_presenter
      CompletionsPresenter.new(
        current_user: current_user,
        current_sp: current_sp,
        decrypted_pii: pii,
        requested_attributes: decorated_sp_session.requested_attributes.map(&:to_sym),
        ial2_requested: ial2_requested?,
        completion_context: needs_completion_screen_reason,
        selected_email_id: user_session[:selected_email_id_for_linked_identity],
      )
    end

    def identity_proofing_required?
      resolved_authn_context_result.identity_proofing?
    end

    def ial2_requested?
      resolved_authn_context_result.identity_proofing_or_ialmax? && current_user.identity_verified?
    end

    def return_to_account
      track_completion_event('account-page')
      redirect_to account_url
    end

    def decider
      CompletionsDecider.new(user_agent: request.user_agent, request_url: sp_session[:request_url])
    end

    def sign_user_out_and_instruct_to_go_back_to_mobile_app
      sign_out
      flash[:info] = t(
        'instructions.go_back_to_mobile_app',
        friendly_name: decorated_sp_session.sp_name,
      )
      redirect_to new_user_session_url
    end

    def analytics_attributes(page_occurence)
      attributes = {
        ial2: resolved_authn_context_result.identity_proofing?,
        ialmax: resolved_authn_context_result.ialmax?,
        service_provider_name: decorated_sp_session.sp_name,
        sp_session_requested_attributes: sp_session[:requested_attributes],
        page_occurence: page_occurence,
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
        needs_completion_screen_reason: needs_completion_screen_reason,
      }

      if (last_enrollment = current_user.in_person_enrollments.last)
        attributes[:in_person_proofing_status] = last_enrollment.status
        attributes[:doc_auth_result] = last_enrollment.doc_auth_result
      end

      if page_occurence.present? && DisposableEmailDomain.disposable?(email_domain)
        attributes[:disposable_email_domain] = email_domain
      end
      attributes
    end

    def email_domain
      @email_domain ||= begin
        email_address = current_user.email_addresses.take.email
        Mail::Address.new(email_address).domain
      end
    end

    def track_completion_event(last_page)
      analytics.user_registration_complete(**analytics_attributes(last_page))
      user_session.delete(:in_account_creation_flow)
    end

    def pii
      Pii::Cacher.new(current_user, user_session).fetch(current_user.active_profile&.id) ||
        Pii::Attributes.new
    end

    def send_in_person_completion_survey
      return unless resolved_authn_context_result.identity_proofing?

      Idv::InPerson::CompletionSurveySender.send_completion_survey(
        current_user,
        current_sp.issuer,
      )
    end
  end
end
