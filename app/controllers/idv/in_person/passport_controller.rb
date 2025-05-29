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

        render :show, locals: extra_view_variables
      end

      def update
        form_params = allowed_params

        results = form.submit(form_params)

        if results.success?
          store_pii(form_params)
          enrollment.update!(document_type: :passport_book)
          analytics.idv_in_person_proofing_passport_submitted(
            **analytics_arguments,
            **results,
          )
          redirect_to idv_in_person_address_path
        else
          render :show, locals: extra_view_variables
        end
      end

      def extra_view_variables
        {
          form:,
          pii:,
          parsed_dob:,
          parsed_expiration:,
        }
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :ipp_passport,
          controller: self,
          next_steps: [:ipp_address],
          preconditions: ->(idv_session:, user:) {
            idv_session.in_person_passports_allowed? &&
            user.has_establishing_in_person_enrollment? &&
            DocumentCaptureSession.find_by(
              uuid: idv_session.document_capture_session_uuid,
            ).passport_status == 'requested'
          },
          undo_step: ->(idv_session:, user:) do
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
      end

      private

      def store_pii(form_params)
        Idv::InPerson::PassportForm::ATTRIBUTES.each do |attr|
          if [:passport_dob, :passport_expiration].include?(attr)
            pii_from_user[attr] = MemorableDateComponent.extract_date_param form_params[attr]
          else
            pii_from_user[attr] = form_params[attr]
          end
        end
      end

      def analytics_arguments
        {
          flow_path: flow_path,
          step: 'passport',
          analytics_id: 'In Person Proofing',
        }.merge(ab_test_analytics_buckets)
          .merge(extra_analytics_properties)
      end

      def enrollment
        current_user.establishing_in_person_enrollment
      end

      def initialize_pii_from_user
        user_session['idv/in_person'] ||= {}
        user_session['idv/in_person']['pii_from_user'] ||= { uuid: current_user.uuid }
      end

      def pii
        data = pii_from_user
        data = data.merge(allowed_params) if params.has_key?(:in_person_passport)
        data.deep_symbolize_keys
      end

      def parsed_dob
        parse_date(pii[:passport_dob])
      end

      def parsed_expiration
        parse_date(pii[:passport_expiration])
      end

      def parse_date(date)
        return nil unless date.present?

        if date.instance_of?(String)
          Date.parse(date)
        elsif date.instance_of?(Hash)
          Date.parse(MemorableDateComponent.extract_date_param(date))
        end
      rescue Date::Error
        # Catch date parsing errors
      end

      def form
        @form ||= Idv::InPerson::PassportForm.new
      end

      def allowed_params
        params.require(:in_person_passport).permit(
          *Idv::InPerson::PassportForm::ATTRIBUTES,
          passport_dob: [
            :month,
            :day,
            :year,
          ],
          passport_expiration: [
            :month,
            :day,
            :year,
          ],
        )
      end
    end
  end
end
