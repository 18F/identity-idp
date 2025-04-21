# frozen_string_literal: true

module Idv
  module InPerson
    class PassportController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :render_404_if_controller_not_enabled
      # before_action :confirm_step_allowed
      before_action :initialize_pii_from_user, only: [:show]

      def show
        analytics.idv_in_person_proofing_passport_visited(**analytics_arguments)

        @idv_in_person_passport_form = Idv::InPerson::PassportForm.new()
      end

      def extra_view_variables
        {
          form:,
          pii:,
          updating_passport: updating_passport?
        }
      end

      private

      def analytics_arguments
        {
          step: 'passport',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
      end

      def form
        @form ||= Idv::InPerson::PassportForm.new()
      end

      def initialize_pii_from_user
        user_session['idv/in_person'] ||= {}
        user_session['idv/in_person']['pii_from_user'] ||= { uuid: current_user.uuid }
      end

      def pii
        data = pii_from_user
        if params.has_key?(:identity_doc) || params.has_key?(:state_id)
          data = data.merge(flow_params)
        end
        data.deep_symbolize_keys
      end

      def render_404_if_controller_not_enabled
        render_not_found unless
          IdentityConfig.store.doc_auth_passports_enabled &&
          idv_session.passport_allowed &&
          IdentityConfig.store.in_person_passports_enabled
      end

      def updating_passport?
        user_session.dig(:idv, :ssn).present?
      end
    end
  end
end
