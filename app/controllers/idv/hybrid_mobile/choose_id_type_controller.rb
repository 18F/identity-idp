# frozen_string_literal: true

module Idv
  module HybridMobile
    class ChooseIdTypeController < ApplicationController
      include Idv::AvailabilityConcern
      include HybridMobileConcern

      before_action :check_valid_document_capture_session
      # before_action :redirect_if_passport_not_available

      def show
        analytics.idv_doc_auth_choose_id_type_visited(**analytics_arguments)
      end

      def update
        @choose_id_type_form = Idv::ChooseIdTypeForm.new

        result = @choose_id_type_form.submit(choose_id_type_form_params)

        analytics.idv_doc_auth_choose_id_type_submitted(
          **analytics_arguments.merge(result.to_h)
              .merge({ chosen_id_type: }),
        )

        if result.success?
          set_passport_requested
          redirect_to next_step
        else
          render :show
        end
      end

      private

      def redirect_if_passport_not_available
        redirect_to correct_vendor_url if document_capture_session.passport_status.blank?
      end

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

      def next_step
        if document_capture_session.passport_status == 'requested'
          idv_hybrid_mobile_document_capture_url # not using socure for passport
        else
          correct_vendor_url
        end
      end

      def choose_id_type_form_params
        params.require(:doc_auth).permit(:choose_id_type_preference)
      end

      def analytics_arguments
        {
          step: 'hybrid_choose_id_type',
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
        }
      end
    end
  end
end
