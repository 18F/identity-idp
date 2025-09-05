# frozen_string_literal: true

module Idv
  module HybridMobile
    class ChooseIdTypeController < ApplicationController
      include Idv::AvailabilityConcern
      include HybridMobileConcern
      include DocumentCaptureConcern
      include Idv::ChooseIdTypeConcern

      before_action :check_valid_document_capture_session

      def show
        analytics.idv_doc_auth_choose_id_type_visited(**analytics_arguments)

        render 'idv/shared/choose_id_type',
               locals: locals_attrs(
                 presenter: Idv::HybridMobile::ChooseIdTypePresenter.new,
                 form_submit_url: idv_hybrid_mobile_choose_id_type_path,
               )
      end

      def update
        @choose_id_type_form = Idv::ChooseIdTypeForm.new

        result = @choose_id_type_form.submit(choose_id_type_form_params)

        analytics.idv_doc_auth_choose_id_type_submitted(
          **analytics_arguments.merge(result.to_h)
              .merge({ chosen_id_type: }),
        )

        if passport_chosen? &&
           !dos_passport_api_healthy?(analytics:, step: 'choose_id_type')
          redirect_to idv_hybrid_mobile_choose_id_type_url(passports: false)
        elsif result.success?
          set_passport_requested
          redirect_to next_step
        else
          redirect_to idv_hybrid_mobile_choose_id_type_url
        end
      end

      private

      def next_step
        idv_hybrid_mobile_document_capture_url
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
