# frozen_string_literal: true

module Idv
  module ChooseIdTypeConcern
    include Idv::PassportCardsConcern

    def chosen_id_type
      choose_id_type_form_params[:choose_id_type_preference]
    end

    def passport_chosen?
      Idp::Constants::DocumentTypes::PASSPORT_TYPES.include?(chosen_id_type)
    end

    def set_passport_requested
      if passport_chosen?
        unless document_capture_session.passport_requested?
          document_capture_session.request_passport!(
            passport_cards_supported: passport_cards_supported?,
          )
        end
      else
        document_capture_session.request_state_id!
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end

    def selected_id_type
      return :state_id_card if document_capture_session.state_id_requested?
      return :passport if document_capture_session.passport_requested?
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
        auto_check_value: disable_passports? ? :state_id_card : selected_id_type,
        passport_cards_enabled: passport_cards_supported? && presenter.passport_card_available?,
      }
    end

    def disable_passports?
      !passports_enabled? ||
        params.permit(:passports)[:passports].present?
    end

    def passports_enabled?
      IdentityConfig.store.doc_auth_passports_enabled || passport_cards_supported?
    end
  end
end
