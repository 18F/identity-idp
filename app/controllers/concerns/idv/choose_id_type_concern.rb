# frozen_string_literal: true

module Idv
  module ChooseIdTypeConcern
    def chosen_id_type
      choose_id_type_form_params[:choose_id_type_preference]
    end

    def set_passport_requested
      if chosen_id_type == 'passport'
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

      request = DocAuth::Dos::Requests::HealthCheckRequest.new(endpoint:)
      response = request.fetch(analytics, context_analytics: { step: })
      response.success?
    end

    def locals_attrs(analytics:, presenter:, form_submit_url: nil)
      dos_passport_api_down = !dos_passport_api_healthy?(analytics:, step: 'choose_id_type')
      {
        presenter:,
        form_submit_url:,
        dos_passport_api_down:,
        auto_check_value: dos_passport_api_down ? :drivers_license : selected_id_type,
      }
    end
  end
end
