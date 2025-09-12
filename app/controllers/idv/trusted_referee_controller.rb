# frozen_string_literal: true

module Idv
  class TrustedRefereeController < ApplicationController
    include RenderConditionConcern
    include Idv::VerifyInfoConcern

    skip_before_action :verify_authenticity_token
    # check_or_render_not_found -> { IdentityConfig.store.trusted_referee_enabled }
    before_action :check_token

    def create
      begin
        log_request
        proof_applicant
      rescue StandardError => e
        byebug
        NewRelic::Agent.notice_error(e)
      ensure
        render json: { message: 'Secret token is valid.' }, status: :ok
      end
    end

    private

    def proof_applicant
      idv_session.ssn = SsnFormatter.normalize(params[:ssn])
      idv_session.phone_for_trusted_referee_flow = params[:phone]
      shared_update
    end

    def check_token
      return
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

    def log_request
      # todo: log event
    end

    def profile_params
      @profile_params ||=
        params.permit(
          :webhook_endpoint,
          :email,
          :first_name,
          :last_name,
          :address1,
          :address2,
          :city,
          :state,
          :zipcode,
          :dob,
          :phone,
          :ssn,
          state_id: {
            state_id_number:,
            jurisdiction:,
            state_id_expiration:,
            state_id_issued:,
          },
          passport: {
            passport_expiration:,
            issuing_country_code:,
            passport_number:,
            passport_issued:,
          },
        )
    end

    def read_pii
      if params.dig('passport')
        Pii::Passport.new(
          first_name: params.dig('first_name'),
          middle_name: params.dig('middle_name'),
          last_name: params.dig('last_name'),
          dob: params.dig('dob'),
          mrz: params.dig('mrz'),
          issuing_country_code: params.dig('paassport', 'issuing_country_code'),
          nationality_code: nil,
          document_number: params.dig('passport', 'issuing_country_code', 'document_number'),
          document_type_received: 'passport',
          passport_expiration: params.dig('passport', 'passport_expiration'),
          sex: nil,
          birth_place: nil,
          passport_issued: nil,
        )
      else
        Pii::StateId.new(
          first_name: params.dig('first_name'),
          middle_name: params.dig('middle_name'),
          last_name: params.dig('last_name'),
          name_suffix: nil,
          address1: params.dig('address1'),
          address2: nil,
          city: params.dig('city'),
          state: params.dig('state'),
          zipcode: params.dig('zipcode'),
          dob: params.dig('dob'),
          sex: nil,
          height: nil,
          weight: nil,
          eye_color: nil,
          state_id_number: params.dig('state_id', 'state_id_number'),
          state_id_issued: params.dig('state_id', 'state_id_issued'),
          state_id_expiration: params.dig('state_id', 'state_id_expiration'),
          document_type_received: 'state_id',
          state_id_jurisdiction: params.dig('state_id', 'jurisdiction'),
          issuing_country_code: 'USA',
        )
      end
    end

    def analytics_arguments
      {
        flow_path: 'trusted referee',
        step: 'verify',
        analytics_id: 'Doc Auth',
      }
    end

    def idv_session
      @idv_session ||= Idv::Session.new(
        user_session:,
        current_user:,
        service_provider:,
      )
    end

    def current_user
      @current_user ||= begin
        email = params.dig('email').downcase
        user = User.find_with_email(email)
        return user if user
        user = User.new
        user.email_addresses.build(
          user: user,
          email: email,
        )
        user.save!
        user
      end
    end

    def user_session
      @user_session ||= {}
    end

    def service_provider
      nil # todo
    end

    def pii
      @pii ||= read_pii.to_h.merge(
        ssn: params[:ssn],
        email: params[:email],
        phone: params[:phone],
      ).with_indifferent_access
    end
  end
end