# frozen_string_literal: true

module Idv
  class TrustedRefereeController < ApplicationController
    include RenderConditionConcern

    skip_before_action :verify_authenticity_token
    # check_or_render_not_found -> { IdentityConfig.store.trusted_referee_enabled }
    # before_action :check_token

    def create
      begin
        log_request
        proof_applicant
      rescue StandardError => e
        NewRelic::Agent.notice_error(e)
      ensure
        render json: { message: 'Secret token is valid.' }, status: :ok
      end
    end

    private

    def proof_applicant
    end


    def check_token
      if !token_valid?
        render status: :unauthorized, json: { message: 'Invalid secret token.' }
      end
    end

    def token_valid?
      authorization_header = request.headers['Authorization']&.split&.last

      authorization_header.present? &&
        (verify_current_key(authorization_header: authorization_header) ||
          verify_queue(authorization_header: authorization_header))
    end

    def verify_current_key(authorization_header:)
      ActiveSupport::SecurityUtils.secure_compare(
        authorization_header,
        IdentityConfig.store.socure_docv_webhook_secret_key,
      )
    end

    def verify_queue(authorization_header:)
      IdentityConfig.store.socure_docv_webhook_secret_key_queue.any? do |key|
        ActiveSupport::SecurityUtils.secure_compare(
          authorization_header,
          key,
        )
      end
    end

    def log_reqquest
      # analytics.idv_doc_auth_socure_webhook_received(
      #   created_at: event[:created],
      #   customer_user_id: event[:customerUserId],
      #   docv_transaction_token:,
      #   event_type: event[:eventType],
      #   reference_id: event[:referenceId],
      #   user_id: user&.uuid,
      # )
    end

    def profile_params
      @profile_params ||=
        params.permit(
          :first_name,
          :last_name,
          :address1,
          :address2,
          :city,
          :state,
          :zipcode,
          :dob,
          state_id: {
            state_id_number:,
            jurisdiction:,
            state_id_expiration:,
            state_id_issued:,
          },
          passport: {
            passport_expiration:,
            issuing_country_code:,
            pasport_number:,
            passport_issued:,
          },
        )
    end

    def read_pii
      if document_type_received == Idp::Constants::DocumentTypes::PASSPORT
        return Pii::Passport.new(
          first_name: get_data(DATA_PATHS[:first_name]),
          middle_name: get_data(DATA_PATHS[:middle_name]),
          last_name: get_data(DATA_PATHS[:last_name]),
          dob:,
          mrz: get_data(DATA_PATHS[:mrz]),
          issuing_country_code:,
          nationality_code: issuing_country_code,
          document_number: get_data(DATA_PATHS[:document_number]),
          document_type_received: document_type_received,
          passport_expiration: expiration_date,
          sex: nil,
          birth_place: nil,
          passport_issued: nil,
        )
      end

      Pii::StateId.new(
        first_name: get_data(DATA_PATHS[:first_name]),
        middle_name: get_data(DATA_PATHS[:middle_name]),
        last_name: get_data(DATA_PATHS[:last_name]),
        name_suffix: nil,
        address1: get_data(DATA_PATHS[:address1]),
        address2:,
        city: get_data(DATA_PATHS[:city]),
        state: get_data(DATA_PATHS[:state]),
        zipcode: get_data(DATA_PATHS[:zipcode]),
        dob:,
        sex: nil,
        height: nil,
        weight: nil,
        eye_color: nil,
        state_id_number: get_data(DATA_PATHS[:document_number]),
        state_id_issued:,
        state_id_expiration: expiration_date,
        document_type_received:,
        state_id_jurisdiction: get_data(DATA_PATHS[:issuing_state]),
        issuing_country_code:,
      )
    end
  end
end