module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :verify_confirmed, if: :ial2?
    before_action :apply_secure_headers_override, only: [:show, :update]

    def show
      @view_model = view_model
      if needs_completions_screen?
        @pii = displayable_attributes
        analytics.track_event(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
          analytics_attributes(''),
        )
      else
        return_to_account
      end
    end

    def update
      track_completion_event('agency-page') if needs_completions_screen?
      handle_verified_attributes
      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to(sp_session_request_url_without_prompt_login || account_url)
      end
    end

    private

    def handle_verified_attributes
      update_verified_attributes
      clear_verify_attributes_sessions
    end

    def view_model
      SignUpCompletionsShow.new(
        ial2_requested: ial2?,
        decorated_session: decorated_session,
        current_user: current_user,
        handoff: new_service_provider_attributes,
        ialmax_requested: ialmax?,
        consent_has_expired: consent_has_expired?,
      )
    end

    def verify_confirmed
      redirect_to idv_url if current_user.decorate.identity_not_verified?
    end

    def ial2?
      sp_session[:ial2] == true
    end

    def ialmax?
      sp_session[:ialmax] == true
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
        friendly_name: view_model.decorated_session.sp_name,
      )
      redirect_to new_user_session_url
    end

    def analytics_attributes(page_occurence)
      { ial2: sp_session[:ial2],
        service_provider_name: decorated_session.sp_name,
        page_occurence: page_occurence }
    end

    def track_completion_event(last_page)
      analytics.track_event(Analytics::USER_REGISTRATION_COMPLETE, analytics_attributes(last_page))
    end

    def pii
      @parsed_pii ||= JSON.parse(user_session['decrypted_pii']).symbolize_keys
    end

    def address
      addr = pii[:address2]
      addr = addr ? "#{addr} " : ''
      "#{pii[:address1]} #{addr}#{pii[:city]}, #{pii[:state]} #{pii[:zipcode]}"
    end

    def full_name
      "#{pii[:first_name]} #{pii[:last_name]}"
    end

    def email
      EmailContext.new(current_user).last_sign_in_email_address.email
    end

    def all_emails
      current_user.confirmed_email_addresses.map(&:email)
    end

    def displayable_attributes
      return pii_to_displayable_attributes if user_session['decrypted_pii'].present?
      {
        email: email,
        all_emails: all_emails,
        verified_at: verified_at,
        x509_subject: current_user.piv_cac_configurations.first&.x509_dn_uuid,
        x509_issuer: current_user.piv_cac_configurations.first&.x509_issuer,
      }
    end

    def dob
      pii_dob = pii[:dob]
      pii_dob ? DateParser.parse_legacy(pii_dob).to_formatted_s(:long) : ''
    end

    def verified_at
      timestamp = current_user.active_profile&.verified_at
      if timestamp
        I18n.l(timestamp, format: :event_timestamp)
      else
        I18n.t('help_text.requested_attributes.verified_at_blank')
      end
    end

    def pii_to_displayable_attributes
      {
        full_name: full_name,
        social_security_number: render_to_string(
          partial: 'shared/masked_text',
          locals: {
            text: SsnFormatter.format(pii[:ssn]),
            masked_text: SsnFormatter.format_masked(pii[:ssn]),
            accessible_masked_text: t(
              'idv.accessible_labels.masked_ssn',
              first_number: pii[:ssn][0],
              last_number: pii[:ssn][-1],
            ),
          },
        ),
        address: address,
        birthdate: dob,
        phone: PhoneFormatter.format(pii[:phone].to_s),
        email: email,
        verified_at: verified_at,
        x509_subject: current_user.piv_cac_configurations.first&.x509_dn_uuid,
        x509_issuer: current_user.piv_cac_configurations.first&.x509_issuer,
      }
    end
  end
end
