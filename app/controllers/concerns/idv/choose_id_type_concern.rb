# frozen_string_literal: true

module Idv
  module ChooseIdTypeConcern
    def chosen_id_type
      choose_id_type_form_params[:choose_id_type_preference]
    end

    def passport_chosen?
      chosen_id_type == 'passport'
    end

    def set_document_type_requested
      case chosen_id_type
      when Idp::Constants::DocumentTypes::PASSPORT
        unless document_capture_session.passport_requested? # needed?
          document_capture_session.request_passport!
        end
      when Idp::Constants::DocumentTypes::MDL
        document_capture_session.request_mdl!
      when Idp::Constants::DocumentTypes::STATE_ID_CARD
        document_capture_session.request_state_id!
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end

    def selected_id_type
      return :state_id_card if document_capture_session.state_id_requested?
      return :passport if document_capture_session.passport_requested?
      return :mobile_drivers_license if document_capture_session.mdl_requested?
    end

    def dos_passport_api_healthy?(
      analytics:,
      step:,
      endpoint: IdentityConfig.store.dos_passport_composite_healthcheck_endpoint
    )
      return true if endpoint.blank?

      Rails.cache.fetch(
        endpoint,
        expires_in: IdentityConfig.store.dos_passport_healthcheck_cache_expiration_seconds,
      ) do
        request = DocAuth::Dos::Requests::HealthCheckRequest.new(endpoint:)
        response = request.fetch(analytics, context_analytics: { step: })
        response.success?
      end
    end

    def locals_attrs(presenter:, form_submit_url: nil)
      {
        presenter:,
        form_submit_url:,
        disable_passports: disable_passports?,
        auto_check_value: disable_passports? && document_capture_session.passport_requested? ?
          nil : document_capture_session.document_type_requested,
      }
    end

    def disable_passports?
      !passports_enabled? ||
        params.permit(:passports)[:passports].present?
    end

    def passports_enabled?
      IdentityConfig.store.doc_auth_passports_enabled ||
        (FeatureManagement.doc_auth_passport_cards_enabled? && in_passport_cards_allowed_bucket?)
    end

    def in_passport_cards_allowed_bucket?
      ab_test_bucket(:DOC_AUTH_PASSPORT_CARDS_ALLOWED) == :doc_auth_passport_cards_allowed
    end
  end
end
