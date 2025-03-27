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
        document_capture_session.update!(passport_status: 'allowed')
      end
    end

    def choose_id_type_form_params
      params.require(:doc_auth).permit(:choose_id_type_preference)
    end
  end
end
