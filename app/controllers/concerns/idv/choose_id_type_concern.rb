# frozen_string_literal: true

module Idv
  module ChooseIdTypeConcern
    def chosen_id_type
      choose_id_type_form_params[:choose_id_type_preference]
    end

    def set_passport_requested
      if chosen_id_type == 'passport'
        document_capture_session.update!(passport_status: 'requested')
      else
        document_capture_session.update!(passport_status: 'not_requested')
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end

    def auto_check_value
      case document_capture_session.passport_status
      when 'requested'
        :passport
      when 'not_requested'
        :drivers_license
      end
    end

    def dos_passport_api_healthy?(
      analytics:,
      endpoint: IdentityConfig.store.dos_passport_composite_healthcheck_endpoint
    )
      return true if endpoint.blank?

      request = DocAuth::Dos::Requests::HealthCheckRequest.new(endpoint:)
      response = request.fetch(analytics)
      response.success?
    end
  end
end
