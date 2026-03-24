# frozen_string_literal: true

module AnalyticsEvents
  module SpEvents

    # Temporary event:
    # Tracks when the AAL value that we are returning to the integration
    # is different from the actual asserted value
    # @param [String] asserted_aal_value The actual AAL value the IdP asserts
    # @param [String] client_id
    # @param [String] response_aal_value The AAL value the IdP returns via attributes
    def asserted_aal_different_from_response_aal(
      asserted_aal_value:,
      client_id:,
      response_aal_value:,
      **extra
    )
      track_event(
        :asserted_aal_different_from_response_aal,
        asserted_aal_value:,
        client_id:,
        response_aal_value:,
        **extra,
      )
    end

    # @param [String, nil] issuer
    # @param [Integer, nil] requested_events_count
    # @param [Integer, nil] requested_acknowledged_events_count
    # @param [Integer, nil] returned_events_count
    # @param [Integer, nil] acknowledged_events_count
    # @param [Boolean] success
    def attempts_api_poll_events_request(
      issuer:,
      requested_events_count:,
      requested_acknowledged_events_count:,
      returned_events_count:,
      acknowledged_events_count:,
      success:,
      **extra
    )
      track_event(
        :attempts_api_poll_events_request,
        issuer:,
        requested_events_count:,
        requested_acknowledged_events_count:,
        returned_events_count:,
        acknowledged_events_count:,
        success:,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [String] client_id
    # @param [Boolean] client_id_parameter_present
    # @param [Boolean] id_token_hint_parameter_present
    # @param [Boolean] sp_initiated
    # @param [Boolean] oidc
    # @param [Boolean] saml_request_valid
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] method
    # @param [String] original_method Method of referring request
    # OIDC Logout Requested
    def oidc_logout_requested(
      success:,
      error_details: nil,
      client_id: nil,
      sp_initiated: nil,
      oidc: nil,
      client_id_parameter_present: nil,
      id_token_hint_parameter_present: nil,
      saml_request_valid: nil,
      method: nil,
      original_method: nil,
      **extra
    )
      track_event(
        'OIDC Logout Requested',
        success: success,
        client_id: client_id,
        client_id_parameter_present: client_id_parameter_present,
        id_token_hint_parameter_present: id_token_hint_parameter_present,
        error_details: error_details,
        sp_initiated: sp_initiated,
        oidc: oidc,
        saml_request_valid: saml_request_valid,
        method: method,
        original_method: original_method,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [String] client_id
    # @param [Boolean] client_id_parameter_present
    # @param [Boolean] id_token_hint_parameter_present
    # @param [Boolean] sp_initiated
    # @param [Boolean] oidc
    # @param [Boolean] saml_request_valid
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] method
    # OIDC Logout Submitted
    def oidc_logout_submitted(
      success: nil,
      client_id: nil,
      sp_initiated: nil,
      oidc: nil,
      client_id_parameter_present: nil,
      id_token_hint_parameter_present: nil,
      saml_request_valid: nil,
      error_details: nil,
      method: nil,
      **extra
    )
      track_event(
        'OIDC Logout Submitted',
        success: success,
        client_id: client_id,
        client_id_parameter_present: client_id_parameter_present,
        id_token_hint_parameter_present: id_token_hint_parameter_present,
        error_details: error_details,
        sp_initiated: sp_initiated,
        oidc: oidc,
        saml_request_valid: saml_request_valid,
        method: method,
        **extra,
      )
    end

    # @param [Boolean] success Whether form validation was successful
    # @param [String] client_id
    # @param [Boolean] client_id_parameter_present
    # @param [Boolean] id_token_hint_parameter_present
    # @param [Boolean] sp_initiated
    # @param [Boolean] oidc
    # @param [Boolean] saml_request_valid
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] method
    # OIDC Logout Visited
    def oidc_logout_visited(
      success:,
      client_id: nil,
      sp_initiated: nil,
      oidc: nil,
      client_id_parameter_present: nil,
      id_token_hint_parameter_present: nil,
      saml_request_valid: nil,
      error_details: nil,
      method: nil,
      **extra
    )
      track_event(
        'OIDC Logout Page Visited',
        success: success,
        client_id: client_id,
        client_id_parameter_present: client_id_parameter_present,
        id_token_hint_parameter_present: id_token_hint_parameter_present,
        error_details: error_details,
        sp_initiated: sp_initiated,
        oidc: oidc,
        saml_request_valid: saml_request_valid,
        method: method,
        **extra,
      )
    end

    # Tracks when a sucessful openid authorization request is returned
    # @param [Boolean] success Whether form validations were succcessful
    # @param [Boolean] user_sp_authorized Whether user granted consent during this authorization
    # @param [String] client_id
    # @param [String] code_digest hash of returned "code" param
    def openid_connect_authorization_handoff(
      success:,
      user_sp_authorized:,
      client_id:,
      code_digest:,
      **extra
    )
      track_event(
        'OpenID Connect: authorization request handoff',
        success:,
        user_sp_authorized:,
        client_id:,
        code_digest:,
        **extra,
      )
    end

    # Tracks when an openid connect bearer token authentication request is made
    # @param [Boolean] success Whether form validation was successful
    # @param [Integer] ial
    # @param [String] client_id Service Provider issuer
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    def openid_connect_bearer_token(success:, ial:, client_id:, error_details: nil, **extra)
      track_event(
        'OpenID Connect: bearer token authentication',
        success:,
        ial:,
        client_id:,
        error_details:,
        **extra,
      )
    end

    # Tracks when openid authorization request is made
    # @param [Boolean] success Whether form validations were succcessful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] prompt OIDC prompt parameter
    # @param [Boolean] allow_prompt_login Whether service provider is configured to allow prompt=login
    # @param [Boolean] code_challenge_present Whether code challenge is present
    # @param [Boolean, nil] service_provider_pkce Whether service provider is configured with PKCE
    # @param [String, nil] referer Request referer
    # @param [String] client_id
    # @param [String] scope
    # @param [Array] acr_values
    # @param [Boolean] unauthorized_scope
    # @param [Boolean] user_fully_authenticated
    # @param [String] unknown_authn_contexts space separated list of unknown contexts
    def openid_connect_request_authorization(
      success:,
      prompt:,
      allow_prompt_login:,
      code_challenge_present:,
      service_provider_pkce:,
      referer:,
      client_id:,
      scope:,
      acr_values:,
      unauthorized_scope:,
      user_fully_authenticated:,
      error_details: nil,
      unknown_authn_contexts: nil,
      **extra
    )
      track_event(
        'OpenID Connect: authorization request',
        success:,
        error_details:,
        prompt:,
        allow_prompt_login:,
        code_challenge_present:,
        service_provider_pkce:,
        referer:,
        client_id:,
        scope:,
        acr_values:,
        unauthorized_scope:,
        user_fully_authenticated:,
        unknown_authn_contexts:,
        **extra,
      )
    end

    # Tracks when an openid connect token request is made
    # @param [Boolean] success Whether the form was submitted successfully.
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] client_id Service provider issuer
    # @param [String] user_id User ID associated with code
    # @param [String] code_digest hash of "code" param
    # @param [Integer, nil] expires_in time to expiration of token
    # @param [Integer, nil] ial ial level of identity
    # @param [Boolean] code_verifier_present Whether code verifier parameter was present
    # @param [Boolean, nil] service_provider_pkce Whether service provider is configured for PKCE. Nil
    # if the service provider is unknown.
    def openid_connect_token(
      client_id:,
      success:,
      user_id:,
      code_digest:,
      expires_in:,
      ial:,
      code_verifier_present:,
      service_provider_pkce:,
      error_details: nil,
      **extra
    )
      track_event(
        'OpenID Connect: token',
        success:,
        error_details:,
        client_id:,
        user_id:,
        code_digest:,
        expires_in:,
        ial:,
        code_verifier_present:,
        service_provider_pkce:,
        **extra,
      )
    end

    # User cancelled the process and returned to the sp
    # @param [String] redirect_url the url of the service provider
    # @param [String] flow
    # @param [String] step
    # @param [String] location
    def return_to_sp_cancelled(
      redirect_url:,
      step: nil,
      location: nil,
      flow: nil,
      **extra
    )
      track_event(
        'Return to SP: Cancelled',
        redirect_url: redirect_url,
        step: step,
        location: location,
        flow: flow,
        **extra,
      )
    end

    # Tracks when a user is redirected back to the service provider after failing to proof.
    # @param [String] redirect_url the url of the service provider
    # @param [String] flow
    # @param [String] step
    # @param [String] location
    def return_to_sp_failure_to_proof(redirect_url:, flow: nil, step: nil, location: nil, **extra)
      track_event(
        'Return to SP: Failed to proof',
        redirect_url: redirect_url,
        flow: flow,
        step: step,
        location: location,
        **extra,
      )
    end

    # Record SAML authentication payload Hash
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [String] nameid_format The NameID format sent in the response
    # @param [String] requested_nameid_format The NameID format requested
    # @param [Array] authn_context
    # @param [String] authn_context_comparison
    # @param [String] service_provider
    # @param [String] endpoint
    # @param [Boolean] idv
    # @param [Boolean] finish_profile
    # @param [String] requested_ial
    # @param [Boolean] request_signed
    # @param [String] matching_cert_serial matches the request certificate in a successful, signed
    #   request
    # @param [Hash] cert_error_details Details for errors that occurred because of an invalid
    #   signature
    # @param [String] unknown_authn_contexts space separated list of unknown contexts
    def saml_auth(
      success:,
      nameid_format:,
      requested_nameid_format:,
      authn_context:,
      authn_context_comparison:,
      service_provider:,
      endpoint:,
      idv:,
      finish_profile:,
      requested_ial:,
      request_signed:,
      matching_cert_serial:,
      error_details: nil,
      cert_error_details: nil,
      unknown_authn_contexts: nil,
      **extra
    )
      track_event(
        'SAML Auth',
        success:,
        error_details:,
        nameid_format:,
        requested_nameid_format:,
        authn_context:,
        authn_context_comparison:,
        service_provider:,
        endpoint:,
        idv:,
        finish_profile:,
        requested_ial:,
        request_signed:,
        matching_cert_serial:,
        cert_error_details:,
        unknown_authn_contexts:,
        **extra,
      )
    end

    # @param [String] requested_ial
    # @param [Array] authn_context
    # @param [String, nil] requested_aal_authn_context
    # @param [Boolean] force_authn
    # @param [Boolean] final_auth_request
    # @param [String] service_provider
    # @param [Boolean] request_signed
    # @param [String] matching_cert_serial
    # @param [String] unknown_authn_contexts space separated list of unknown contexts
    # @param [Boolean] user_fully_authenticated
    # An external request for SAML Authentication was received
    def saml_auth_request(
      requested_ial:,
      authn_context:,
      requested_aal_authn_context:,
      force_authn:,
      final_auth_request:,
      service_provider:,
      request_signed:,
      matching_cert_serial:,
      unknown_authn_contexts:,
      user_fully_authenticated:,
      **extra
    )
      track_event(
        'SAML Auth Request',
        requested_ial:,
        authn_context:,
        requested_aal_authn_context:,
        force_authn:,
        final_auth_request:,
        service_provider:,
        request_signed:,
        matching_cert_serial:,
        unknown_authn_contexts:,
        user_fully_authenticated:,
        **extra,
      )
    end

    # Tracks when a user is bounced back from the service provider due to an integration issue.
    def sp_handoff_bounced_detected
      track_event('SP handoff bounced detected')
    end

    # Tracks when a user visits the bounced page.
    def sp_handoff_bounced_visit
      track_event('SP handoff bounced visited')
    end

    # Tracks when a user visits the "This agency no longer uses Login.gov" page.
    def sp_inactive_visit
      track_event('SP inactive visited')
    end

    # @param [Array] error_details Full messages of the errors
    # @param [Hash] error_types Types of errors that are surfaced
    # @param [Symbol] event What part of the workflow the error occured in
    # @param [Boolean] integration_exists Whether the requesting issuer maps to an SP
    # @param [String] request_issuer The issuer in the request
    # Monitoring service-provider specific integration errors
    def sp_integration_errors_present(
      error_details:,
      error_types:,
      event:,
      integration_exists:,
      request_issuer: nil,
      **extra
    )
      types = error_types.index_with { |_type| true }
      track_event(
        :sp_integration_errors_present,
        error_details:,
        error_types: types,
        event:,
        integration_exists:,
        request_issuer:,
        **extra,
      )
    end

    # Tracks when a user is redirected back to the service provider
    # @param [Integer] ial
    # @param [Integer] billed_ial
    # @param [String, nil] sign_in_flow
    # @param [String, nil] vtr
    # @param [String, nil] acr_values
    # @param [Integer] sign_in_duration_seconds
    def sp_redirect_initiated(
      ial:,
      billed_ial:,
      sign_in_flow:,
      acr_values:,
      sign_in_duration_seconds:,
      vtr: nil,
      **extra
    )
      track_event(
        'SP redirect initiated',
        ial:,
        billed_ial:,
        sign_in_flow:,
        vtr:,
        acr_values:,
        sign_in_duration_seconds:,
        **extra,
      )
    end

    # Tracks when service provider consent is revoked
    # @param [String] issuer issuer of the service provider consent to be revoked
    def sp_revoke_consent_revoked(issuer:, **extra)
      track_event(
        'SP Revoke Consent: Revoked',
        issuer: issuer,
        **extra,
      )
    end

    # Tracks when the page to revoke consent (unlink from) a service provider visited
    # @param [String] issuer which issuer
    def sp_revoke_consent_visited(issuer:, **extra)
      track_event(
        'SP Revoke Consent: Visited',
        issuer: issuer,
        **extra,
      )
    end

    # User submitted form to change email shared with service provider
    # @param [Boolean] success Whether form validation was successful
    # @param [Hash] error_details Details for errors that occurred in unsuccessful submission
    # @param [Integer] selected_email_id Selected email address record ID
    # @param [String, nil] needs_completion_screen_reason Reason for the consent screen being shown,
    #   if user is changing email in consent flow
    def sp_select_email_submitted(
      success:,
      selected_email_id:,
      error_details: nil,
      needs_completion_screen_reason: nil,
      **extra
    )
      track_event(
        :sp_select_email_submitted,
        success:,
        error_details:,
        needs_completion_screen_reason:,
        selected_email_id:,
        **extra,
      )
    end

    # User visited form to change email shared with service provider
    # @param [String, nil] needs_completion_screen_reason Reason for the consent screen being shown,
    #   if user is changing email in consent flow
    def sp_select_email_visited(needs_completion_screen_reason: nil, **extra)
      track_event(:sp_select_email_visited, needs_completion_screen_reason:, **extra)
    end
  end
end
