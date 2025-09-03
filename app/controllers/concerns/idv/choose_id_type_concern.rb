# frozen_string_literal: true

module Idv
  module ChooseIdTypeConcern
    def chosen_id_type
      choose_id_type_form_params[:choose_id_type_preference]
    end

    def passport_chosen?
      chosen_id_type == 'passport'
    end

    def set_passport_requested
      if passport_chosen?
        unless document_capture_session.passport_requested?
          document_capture_session.update!(
            passport_status: 'requested',
            doc_auth_vendor: nil,
          )
        end
      else
        document_capture_session.update!(
          passport_status: 'not_requested',
          doc_auth_vendor: nil,
        )
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end

    def selected_id_type
      case document_capture_session.passport_status
      when 'requested'
        :passport
      when 'not_requested'
        :drivers_license
      end
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
      disable_passports = params.permit(:passports)[:passports].present?
      {
        presenter:,
        form_submit_url:,
        disable_passports:,
        auto_check_value: disable_passports ? :drivers_license : selected_id_type,
      }
    end
  end
end
