# frozen_string_literal: true

module Idv
  class MdlController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_step_allowed
    before_action :confirm_mdl_enabled

    def show
      okta_client = OktaVdc::Client.new
      @credential_request = okta_client.create_credential_request(
        response_mode: 'direct_post.jwt',
      )
      @session_id = @credential_request.dig('state', 'transactionId')
      request_value = @credential_request.dig('request', 'request')

      # Mobile: deep link to wallet. Desktop: QR code.
      # Both use the same "okta-<jwt>" format that the Okta Credentials
      # Showcase app recognizes. The JWT is URL-encoded for safe
      # transport as a deep link URI.
      if mobile? && request_value
        @wallet_deep_link = "okta-#{request_value}"
      elsif request_value
        @qr_svg = generate_qr_svg("okta-#{request_value}")
      end

      session[:mdl_okta_session_id] = @session_id

      # analytics.idv_mdl_visited
    rescue Faraday::Error => e
      Rails.logger.error("[MdlController] Failed to create credential request: #{e.message}")
      @credential_request = nil
      @session_id = nil
      flash.now[:error] = t('idv.mdl.errors.generic')
    end

    # GET /verify/mdl/status - polling endpoint
    def status
      session_id = session[:mdl_okta_session_id]
      return render json: { status: 'error' }, status: :unprocessable_content if session_id.blank?

      okta_client = OktaVdc::Client.new
      result = okta_client.get_request_status(session_id: session_id)

      if result['status'] == 'COMPLETED'
        auth_response = result['response']
        claims_result = okta_client.get_claims(
          session_id: session_id,
          authorization_response: auth_response,
        )
        pii = extract_pii(claims_result)
        apply_pii_to_session(pii)

        render json: { status: 'complete', redirect: idv_ssn_url }
      elsif result['status'] == 'FAILED' || result['status'] == 'EXPIRED'
        render json: { status: 'failed' }
      else
        render json: { status: 'pending' }
      end
    rescue Faraday::Error => e
      Rails.logger.error("[MdlController] Status check error: #{e.message}")
      render json: { status: 'error' }, status: :unprocessable_content
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

    def extract_pii(claims_result)
      claims = claims_result['claims'] || claims_result
      parser = OktaVdc::ResponseParser.new(claims)

      if parser.parse && parser.success?
        parser.to_pii
      else
        Rails.logger.warn("[MdlController] Using mock PII: #{parser.errors.join(', ')}")
        Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
      end
    end

    def generate_qr_svg(data)
      return nil if data.blank?
      qrcode = RQRCode::QRCode.new(data)
      qrcode.as_svg(
        offset: 0,
        color: '000',
        shape_rendering: 'crispEdges',
        module_size: 4,
        standalone: true,
        use_path: true,
      )
    end

    def apply_pii_to_session(pii)
      idv_session.pii_from_doc = pii
      idv_session.had_barcode_read_failure = false
      idv_session.had_barcode_attention_error = false
      idv_session.selfie_check_performed = false

      idv_session.phone_precheck_successful = true
      idv_session.precheck_phone = {
        source: :mdl,
        phone: current_user.default_phone_configuration&.formatted_phone,
      }
    end
  end
end
