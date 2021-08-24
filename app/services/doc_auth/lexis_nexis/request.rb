module DocAuth
  module LexisNexis
    class Request
      attr_reader :config, :applicant

      def initialize(config:, applicant: nil)
        @config = config
        @applicant = applicant
      end

      def fetch
        http_response = send_http_request
        return handle_invalid_response(http_response) unless http_response.success?

        handle_http_response(http_response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_connection_error(e)
      end

      def metric_name
        raise NotImplementedError
      end

      private

      def send_http_request
        case method.downcase.to_sym
        when :post
          send_http_post_request
        when :get
          send_http_get_request
        end
      end

      def handle_http_response(_response)
        raise NotImplementedError
      end

      def handle_invalid_response(http_response)
        message = [
          self.class.name,
          'Unexpected HTTP response',
          http_response.status,
        ].join(' ')
        exception = DocAuth::RequestError.new(message, http_response.status)

        handle_connection_error(exception)
      end

      def handle_connection_error(exception)
        NewRelic::Agent.notice_error(exception)
        DocAuth::Response.new(
          success: false,
          errors: { network: true },
          exception: exception,
        )
      end

      def send_http_get_request
        faraday_connection.get do |req|
          req.options.context = { service_name: metric_name }
        end
      end

      def send_http_post_request
        faraday_connection.post do |req|
          req.options.context = { service_name: metric_name }
          req.body = body
        end
      end

      def faraday_connection
        retry_options = {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [404, 500],
          retry_block: lambda do |_env, _options, retries, exc|
            NewRelic::Agent.notice_error(exc, custom_params: { retry: retries })
          end,
        }

        Faraday.new(request: faraday_request_params, url: url.to_s, headers: headers) do |conn|
          conn.request :retry, retry_options
          conn.request :instrumentation, name: 'request_metric.faraday'
          conn.basic_auth username, password
          conn.adapter :net_http
        end
      end

      def faraday_request_params
        { open_timeout: timeout, timeout: timeout }
      end

      def path
        "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations"
      end

      def method
        :get
      end

      def url
        URI.join(config.base_url, path)
      end

      def headers
        {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        }
      end

      def settings
        {
          Type: 'Initiate',
          Settings: {
            Mode: request_mode,
            Locale: config.locale,
            Venue: 'online',
            Reference: uuid,
          },
        }
      end

      def uuid
        return SecureRandom.uuid unless applicant

        uuid = applicant.fetch(:uuid, SecureRandom.uuid)
        uuid_prefix = applicant[:uuid_prefix]

        if uuid_prefix.present?
          "#{uuid_prefix}:#{uuid}"
        else
          uuid
        end
      end

      def username
        raise NotImplementedError
      end

      def password
        raise NotImplementedError
      end

      def account_id
        config.account_id
      end

      def workflow
        raise NotImplementedError
      end

      def body
        raise NotImplementedError
      end

      def request_mode
        config.request_mode
      end

      def timeout
        config.timeout&.to_i || 45
      end
    end
  end
end
