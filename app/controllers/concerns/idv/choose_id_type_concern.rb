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

    def set_document_type_requested
      case chosen_id_type
      when *Idp::Constants::DocumentTypes::PASSPORT_TYPES
        unless document_capture_session.passport_requested? # needed?
          document_capture_session.request_passport!(
            passport_cards_supported: passport_cards_supported?,
          )
        end
      when Idp::Constants::DocumentTypes::MDL
        document_capture_session.request_mdl!
      when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
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
      auto_check_value = case document_capture_session.document_type_requested
                        when Idp::Constants::DocumentTypes::MDL
                          :mobile_drivers_license
                        when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
                          :state_id_card
                        when Idp::Constants::DocumentTypes::PASSPORT
                          if disable_passports?
                            :state_id_card
                          else
                            :passport
                          end
                        else
                          :state_id_card
                        end

      {
        presenter:,
        form_submit_url:,
        disable_passports: disable_passports?,
        auto_check_value:,
        passport_cards_enabled: passport_cards_supported? && presenter.passport_card_available?,
        mdl_enabled: mdl_enabled?,
      }
    end

    def disable_passports?
      !passports_enabled? ||
        params.permit(:passports)[:passports].present?
    end

    def passports_enabled?
      IdentityConfig.store.doc_auth_passports_enabled || passport_cards_supported?
    end

    def mdl_enabled?
      document_capture_session.mdl_enabled
    end
  end
end
