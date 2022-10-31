module DocAuth
  module Acuant
    # https://documentation.help/AssureID-Connect/Error%20Codes.html
    # 438, 439, and 440 are frequent errors that we do not want to be notified of
    HANDLED_HTTP_CODES = Set[438, 439, 440]

    class Request
      attr_reader :config

      def initialize(config:)
        @config = config
      end

      def path
        raise NotImplementedError
      end

      def body
        raise NotImplementedError
      end

      def metric_name
        raise NotImplementedError
      end

      def handle_http_response(_response)
        raise NotImplementedError
      end

      def method
        :get
      end

      def url
        URI.join(config.assure_id_url, path)
      end

      def headers
        {
          'Accept' => 'application/json',
        }
      end

      def fetch
        http_response = send_http_request

        if http_response.success?
          handle_http_response(http_response)
        elsif HANDLED_HTTP_CODES.include?(http_response.status)
          handle_expected_http_error(http_response)
        else
          handle_invalid_response(http_response)
        end
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_connection_error(e)
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
          retry_statuses: [404],
          retry_block: lambda do |_env, _options, retries, exc|
            send_exception_notification(exc, retry: retries)
          end,
        }

        Faraday.new(url: url.to_s, headers: headers) do |conn|
          conn.request :authorization, :basic, config.assure_id_username, config.assure_id_password
          conn.request :instrumentation, name: 'request_metric.faraday'
          conn.request :retry, retry_options
          conn.adapter :net_http

          conn.options.timeout = timeout
          conn.options.read_timeout = timeout
          conn.options.open_timeout = timeout
          conn.options.write_timeout = timeout
        end
      end

      def timeout
        IdentityConfig.store.acuant_timeout
      end

      def create_http_exception(http_response)
        message = [
          self.class.name,
          'Unexpected HTTP response',
          http_response.status,
        ].join(' ')
        DocAuth::RequestError.new(message, http_response.status)
      end

      def create_error_response(errors, exception)
        DocAuth::Response.new(
          success: false,
          errors: errors,
          exception: exception,
          extra: { vendor: 'Acuant' },
        )
      end

      def handle_expected_http_error(http_response)
        error = case http_response.status
          when 438
            Errors::IMAGE_LOAD_FAILURE
          when 439
            Errors::PIXEL_DEPTH_FAILURE
          when 440
            Errors::IMAGE_SIZE_FAILURE
        end

        create_error_response({ general: [error] }, create_http_exception(http_response))
      end

      def handle_invalid_response(http_response)
        exception = create_http_exception(http_response)
        handle_connection_error(exception)
      end

      def handle_connection_error(exception)
        send_exception_notification(exception)
        create_error_response({ network: true }, exception)
      end

      def send_exception_notification(exception, custom_params = {})
        return if exception.is_a?(DocAuth::RequestError) &&
                  HANDLED_HTTP_CODES.include?(exception.error_code)
        NewRelic::Agent.notice_error(exception, custom_params)
      end
    end
  end
end
