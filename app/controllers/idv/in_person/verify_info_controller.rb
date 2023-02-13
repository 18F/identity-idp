module Idv
  module InPerson
    class VerifyInfoController < ApplicationController
#      include IdvSession

      before_action :renders_404_if_flag_not_set
      before_action :confirm_two_factor_authenticated
      before_action :confirm_ssn_step_complete
      before_action :confirm_profile_not_already_confirmed

      def show
        @in_person_proofing = true
        @which_verify_controller = idv_in_person_verify_info_path

        render 'idv/verify_info/show'
      end

      private

      def renders_404_if_flag_not_set
        render_not_found unless IdentityConfig.store.doc_auth_in_person_verify_info_controller_enabled
      end

      ##### Move to VerifyInfoConcern

      def confirm_profile_not_already_confirmed
        return unless idv_session.profile_confirmation == true
        redirect_to idv_review_url
      end
    end
  end
end