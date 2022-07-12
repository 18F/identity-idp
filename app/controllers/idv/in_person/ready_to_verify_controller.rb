module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_session

      def show
        analytics.idv_in_person_ready_to_verify_visit
      end

      private

      def confirm_in_person_session
        redirect_to account_url unless in_person_proofing_component?
      end

      def in_person_proofing_component?
        ProofingComponent.find_by(user: current_user)&.document_check == DocAuth::Vendors::USPS
      end
    end
  end
end
