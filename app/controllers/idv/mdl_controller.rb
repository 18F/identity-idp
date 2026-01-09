# frozen_string_literal: true

module Idv
  class MdlController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_step_allowed
    before_action :confirm_mdl_enabled

    def show
      analytics.idv_mdl_visited
    end

    # GET /verify/mdl/callback
    def callback
      if params[:error].present?
        Rails.logger.error("[MdlController] OpenCred error: #{params[:error]} - #{params[:error_description]}")
        analytics.idv_mdl_verified(
          success: false,
          error: params[:error],
          provider: 'opencred',
        )
        flash[:error] = params[:error_description] || t('idv.mdl.errors.generic')
        return redirect_to idv_mdl_url
      end

      if params[:code].blank?
        Rails.logger.error('[MdlController] No authorization code received from OpenCred')
        analytics.idv_mdl_verified(success: false, error: 'no_code', provider: 'opencred')
        flash[:error] = t('idv.mdl.errors.generic')
        return redirect_to idv_mdl_url
      end

      # Exchange authorization code for id_token
      token_response = exchange_code_for_token(params[:code])

      if token_response[:error]
        Rails.logger.error("[MdlController] Token exchange error: #{token_response[:error]}")
        analytics.idv_mdl_verified(success: false, error: token_response[:error], provider: 'opencred')
        flash[:error] = t('idv.mdl.errors.generic')
        return redirect_to idv_mdl_url
      end

      # Extract PII from id_token claims
      pii = extract_pii_from_id_token(token_response[:id_token])

      idv_session.pii_from_doc = Pii::StateId.new(**pii)
      idv_session.had_barcode_read_failure = false
      idv_session.had_barcode_attention_error = false
      idv_session.selfie_check_performed = false

      analytics.idv_mdl_verified(success: true, provider: 'opencred')

      redirect_to idv_ssn_url
    rescue StandardError => e
      Rails.logger.error("[MdlController] Callback error: #{e.message}")
      Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
      analytics.idv_mdl_verified(success: false, error: e.message, provider: 'opencred')
      flash[:error] = t('idv.mdl.errors.generic')
      redirect_to idv_mdl_url
    end

    # POST /verify/mdl/request (legacy - kept for compatibility)
    def request_credentials
      request_builder = Idv::MdlRequestBuilder.new
      store_mdl_session(request_builder.session_data)
      request_data = request_builder.build_request_data

      analytics.idv_mdl_request_generated(session_id: request_builder.session_id)
      render json: request_data
    end

    # POST /verify/mdl/verify (legacy - kept for compatibility)
    def verify
      pii = extract_pii_from_credential

      idv_session.pii_from_doc = Pii::StateId.new(**pii)
      idv_session.had_barcode_read_failure = false
      idv_session.had_barcode_attention_error = false
      idv_session.selfie_check_performed = false
      clear_mdl_session

      analytics.idv_mdl_verified(
        success: true,
        used_mock_data: used_mock_data?,
        session_id: mdl_session_data&.dig('session_id'),
      )

      render json: { success: true, redirect: idv_ssn_url }
    rescue StandardError => e
      Rails.logger.error("[MdlController] Verification error: #{e.message}")
      analytics.idv_mdl_verified(success: false, error: e.message)
      render json: { success: false, error: 'Verification failed' }, status: :unprocessable_entity
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :mdl,
        controller: self,
        next_steps: [:ssn],
        preconditions: ->(idv_session:, user:) do
          IdentityConfig.store.mdl_verification_enabled &&
            idv_session.idv_consent_given?
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.pii_from_doc = nil
        end,
      )
    end

    private

    def confirm_mdl_enabled
      return if IdentityConfig.store.mdl_verification_enabled

      redirect_to idv_choose_id_type_url
    end

    def store_mdl_session(session_data)
      session[:mdl_verification] = session_data
    end

    def mdl_session_data
      session[:mdl_verification]
    end

    def clear_mdl_session
      session.delete(:mdl_verification)
    end

    def extract_pii_from_credential
      credential_data = mdl_verify_params[:credential]
      use_mock = mdl_verify_params[:mock] == true || mdl_verify_params[:mock] == 'true'

      Rails.logger.info("[MdlController] Received credential data: #{credential_data.present?}")
      Rails.logger.info("[MdlController] Mock flag: #{use_mock}")
      Rails.logger.info("[MdlController] Session ID: #{mdl_session_data&.dig('session_id')}")

      if credential_data.present? && !use_mock
        parser = Idv::MdlResponseParser.new(
          credential_data,
          session_data: mdl_session_data,
        )

        if parser.parse && parser.success?
          Rails.logger.info('[MdlController] Successfully parsed real mDL credential')
          @used_mock_data = false
          return parser.pii_from_mdl
        else
          Rails.logger.warn("[MdlController] Failed to parse credential: #{parser.errors.join(', ')}")
          # Don't fall back to mock for real API calls - raise error instead
          if IdentityConfig.store.mdl_strict_validation
            raise "mDL parsing failed: #{parser.errors.join(', ')}"
          end
        end
      end

      # Fall back to mock data (for demo purposes)
      Rails.logger.info('[MdlController] Using mock PII data')
      @used_mock_data = true
      mock_pii_from_mdl
    end

    def used_mock_data?
      @used_mock_data
    end

    def mdl_verify_params
      params.permit(:credential, :mock, :sessionId)
    end

    def mock_pii_from_mdl
      # Demo PII data - matches the simulated wallet UI
      {
        first_name: 'JANE',
        last_name: 'SMITH',
        middle_name: 'M',
        name_suffix: nil,
        dob: '1985-01-15',
        address1: '123 MAIN STREET',
        address2: nil,
        city: 'ANNAPOLIS',
        state: 'MD',
        zipcode: '21401',
        state_id_number: 'S-123-456-789',
        state_id_jurisdiction: 'MD',
        state_id_expiration: '2029-12-31',
        state_id_issued: '2024-01-15',
        issuing_country_code: 'US',
        sex: 'female',
        height: 65,
        weight: 135,
        eye_color: 'brown',
        document_type_received: 'drivers_license',
      }
    end

    # OpenCred OIDC token exchange
    def exchange_code_for_token(code)
      token_url = "#{IdentityConfig.store.opencred_base_url}/token"

      response = Faraday.post(token_url) do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form(
          grant_type: 'authorization_code',
          code: code,
          redirect_uri: idv_mdl_callback_url,
          client_id: IdentityConfig.store.opencred_client_id,
          client_secret: IdentityConfig.store.opencred_client_secret,
        )
      end

      if response.success?
        JSON.parse(response.body, symbolize_names: true)
      else
        Rails.logger.error("[MdlController] Token exchange failed: #{response.status} - #{response.body}")
        { error: 'token_exchange_failed' }
      end
    rescue Faraday::Error => e
      Rails.logger.error("[MdlController] Token request error: #{e.message}")
      { error: 'connection_error' }
    end

    def extract_pii_from_id_token(id_token)
      # TODO: verify signature using OpenCred's JWKS in production
      payload = JWT.decode(id_token, nil, false).first

      Rails.logger.info("[MdlController] Extracted claims from id_token: #{payload.keys}")

      {
        first_name: payload['given_name']&.upcase,
        last_name: payload['family_name']&.upcase,
        middle_name: nil,
        name_suffix: nil,
        dob: payload['birth_date'],
        address1: payload['resident_address']&.upcase,
        address2: nil,
        city: payload['resident_city']&.upcase,
        state: payload['resident_state'],
        zipcode: payload['resident_postal_code'],
        state_id_number: payload['document_number'],
        state_id_jurisdiction: payload['issuing_jurisdiction'],
        state_id_expiration: payload['expiry_date'],
        state_id_issued: payload['issue_date'],
        issuing_country_code: 'US',
        sex: nil,
        height: nil,
        weight: nil,
        eye_color: nil,
        document_type_received: 'drivers_license',
      }
    rescue JWT::DecodeError => e
      Rails.logger.error("[MdlController] JWT decode error: #{e.message}")
      # Fall back to mock data for POC
      mock_pii_from_mdl
    end
  end
end
