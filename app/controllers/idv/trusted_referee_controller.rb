# frozen_string_literal: true

module Idv
  class TrustedRefereeController < ApplicationController
    include RenderConditionConcern
    include Idv::VerifyInfoConcern
    include EnterPasswordConcern

    skip_before_action :verify_authenticity_token
    # check_or_render_not_found -> { IdentityConfig.store.trusted_referee_enabled }
    before_action :check_token

    def create
      begin
        log_request
        validate_pii
        validate_webhook_endpoint
        proof_applicant
        # proofing_result = await_result
        # process_result(proofing_result)
        head :ok
      rescue StandardError => e
        puts e.inspect
        render json: {}, status: :bad_request
        byebug
        NewRelic::Agent.notice_error(e)
        # send failure response
      ensure
        # log to analytics
      end
    end

    def webhook
      byebug
      body = webhook_params.except(:webhook_endpoint)
      endpoint = webhook_params[:endpoint]

      response = send_http_post_request(endpoint:, body:)
    rescue => exception
      NewRelic::Agent.notice_error(
        exception,
        custom_params: {
          event: 'Failed to send webhook',
          endpoint:,
          body:,
        },
      )
    ensure
      puts response.inspect
      # log to analytics
    end

    def result
      result_id = params.permit(:result_id)[:result_id]
      dcs_uuid = DocumentCaptureSession.find_by(result_id:)
      idv_session.verify_info_step_document_capture_session_uuid = dcs_uuid
      proofing_result = load_async_state
      process_result(proofing_result)

      profile = current_user&.profiles.last
      body = {}
      if profile
        body = { uuid: profile.uuid, active: profile.active }
      end
      render json: {}, status: :ok
    rescue => exception
      puts exception.inspect
      render json: {}, status: :bad_request
      NewRelic::Agent.notice_error(
        exception,
        custom_params: {
          event: 'Failed to respond to result',
          body:,
        },
      )
    ensure
      # log to analytics
    end

    private

    def validate_pii
      # todo return 400 if invalid
    end

    def await_result
      i = 0
      proofing_job_result = load_async_state
      until proofing_job_result.done?
        break if i > 60
        sleep(1)
        i += 1
        proofing_job_result = load_async_state
      end
      proofing_job_result
    end

    def process_result(proofing_result)
      if proofing_result.done? && proofing_result.result[:success] == true ## && phone_pre_check success?
        move_applicant_to_idv_session
        init_profile # where to call this?
      else
        byebug
        # send failure response
      end
    end

    def proof_applicant
      idv_session.ssn = SsnFormatter.normalize(params[:ssn])
      idv_session.phone_for_trusted_referee_flow = params[:phone]
      idv_session.webhook_for_trusted_referee_flow = webhook_endpoint # || IdentityConfig.store.trusted_referre_webhook_endpoint
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
        verify_key(authorization_header: authorization_header)
    end

    def verify_key(authorization_header:)
      # IdentityConfig.store.trusted_referee_secret_key_queue.any? do |key|
      #   ActiveSupport::SecurityUtils.secure_compare(
      #     authorization_header,
      #     key,
      #   )
      # end
    end

    def log_request
      # todo: log event
    end

    def profile_params
      @profile_params ||=
        params.permit(
          :request_id,
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
          state_id: [
            :state_id_number,
            :jurisdiction,
            :state_id_expiration,
            :state_id_issued,
          ],
          passport: [
            :passport_expiration,
            :issuing_country_code,
            :passport_number,
            :passport_issued,
          ],
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
        user = nil

        if(email = params.dig('email')&.downcase)
          user = User.find_with_email(email)
          return user if user
          user = User.new(email:, password:, password_confirmation: password)
          user.email_addresses.build(
            user: user,
            email: email,
          )
          user.save!
        elsif dcs_uuid
          user = DocumentCaptureSession.find_by(uuid: dcs_uuid)&.user
        end
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

    def password
      @password ||= Random.hex
    end

    def send_http_post_request(endpoint:, body:)
      faraday_connection(endpoint).post do |req|
        req.options.context = { service_name: 'trusted_referee webhook' }
        req.body = body.to_json
      end
    end

    def faraday_connection(endpoint)
      retry_options = {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [404, 500],
        retry_block: lambda do |env:, options:, retry_count:, exception:, will_retry_in:|
          NewRelic::Agent.notice_error(exception, custom_params: { retry: retry_count })
        end,
      }

      timeout = 15

      Faraday.new(url: url(endpoint).to_s, headers: request_headers) do |conn|
        conn.request :retry, retry_options
        conn.request :instrumentation, name: 'request_metric.faraday'
        conn.adapter :net_http
        conn.options.timeout = timeout
        conn.options.read_timeout = timeout
        conn.options.open_timeout = timeout
        conn.options.write_timeout = timeout
      end
    end

    def url(endpoint)
      URI.join(endpoint)
    end

    def request_headers(extras = {})
      # headers.merge(extras)
      extras
    end

    def webhook_params
      params.permit(:uid, :request_id, :webhook_endpoint, :pid, :reason)
    end

    def webhook_endpoint
      @webhook_endpoint ||= profile_params[:webhook_endpoint] ||
                            IdentityConfig.store.trusted_referee_webhook_endpoint
    end

    def validate_webhook_endpoint
      # todo return 400 if invalid
    end

    def trusted_referee_webhook_endpoint
      webhook_endpoint
    end

    def trusted_referee_request_id
      profile_params[:request_id]
    end

    def dcs_uuid
      @document_capture_session_uuid ||= params.permit(:dcs_uuid)[:dcs_uuid]
    end
  end
end
