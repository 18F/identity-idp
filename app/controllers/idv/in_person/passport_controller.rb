# frozen_string_literal: true

module Idv
  module InPerson
    class PassportController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :confirm_step_allowed
      before_action :initialize_pii_from_user, only: [:show]

      def show
        analytics.idv_in_person_proofing_passport_visited(**analytics_arguments)
      end

      def extra_view_variables
        {
          form:,
          pii:,
        }
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_passport,
          controller: self,
          next_steps: [:ipp_address],
          preconditions: ->(idv_session:, user:) {
            idv_session.in_person_passports_allowed? && user.has_establishing_in_person_enrollment?
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
      end

      private

      def analytics_arguments
        {
          step: 'passport',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
      end

      def initialize_pii_from_user
        user_session['idv/in_person'] ||= {}
        user_session['idv/in_person']['pii_from_user'] ||= { uuid: current_user.uuid }
      end

      def pii
        data = pii_from_user
        if params.has_key?(:identity_doc) || params.has_key?(:in_person_passport)
          data = data.merge(flow_params)
        end
        data.deep_symbolize_keys
      end
    end
  end
end
