# frozen_string_literal: true

module Idv
  module InPerson
    class PassportController < ApplicationController
      # include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :render_404_if_controller_not_enabled
      # before_action :set_usps_form_presenter
      # before_action :confirm_step_allowed
      before_action :initialize_pii_from_user, only: [:show]

      def show
        # analytics.idv_in_person_proofing_state_id_visited(**analytics_arguments)

        render :show, locals: extra_view_variables
      end


      def extra_view_variables
        {
          form:,
        #   pii:,
        #   parsed_dob:,
        #   updating_state_id: updating_state_id?,
        }
      end

      private

      def form
        @form ||= Idv::InPerson::PassportForm.new()
      end

      def initialize_pii_from_user
        user_session['idv/in_person'] ||= {}
        user_session['idv/in_person']['pii_from_user'] ||= { uuid: current_user.uuid }
      end

      def render_404_if_controller_not_enabled
        render_not_found unless
          IdentityConfig.store.doc_auth_passports_enabled &&
          idv_session.passport_allowed &&
          IdentityConfig.store.in_person_passports_enabled
      end
    end
  end
end
