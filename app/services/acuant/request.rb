module Acuant
  class Request
    def path
      raise NotImplementedError
    end

    def body
      raise NotImplementedError
    end

    def handle_http_response(_response)
      raise NotImplementedError
    end

    def method
      :get
    end

    def url
      URI.join(Figaro.env.acuant_assure_id_url, path)
    end

    def headers
      {
        'Accept' => 'application/json',
      }
    end

    def fetch
      http_response = send_http_request
      return handle_invalid_response(http_response) unless http_response.success?

      handle_http_response(http_response)
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
      faraday_connection.get
    end

    def send_http_post_request
      faraday_connection.post do |req|
        req.body = body
      end
    end

    def faraday_connection
      Faraday.new(request: faraday_request_params, url: url.to_s, headers: headers) do |conn|
        conn.adapter :net_http
        conn.basic_auth(
          Figaro.env.acuant_assure_id_username,
          Figaro.env.acuant_assure_id_password,
        )
      end
    end

    def faraday_request_params
      timeout = Figaro.env.acuant_timeout&.to_i || 45
      { open_timeout: timeout, timeout: timeout }
    end

    def handle_invalid_response(http_response)
      message = [
        self.class.name,
        'Unexpected HTTP response',
        http_response.status,
      ].join(' ')
      exception = RuntimeError.new(message)
      Response.new(
        success: false,
        errors: [I18n.t('errors.doc_auth.acuant_network_error')],
        exception: exception,
      )
    end

    def handle_connection_error(exception)
      NewRelic::Agent.notice_error(exception)
      Response.new(
        success: false,
        errors: [I18n.t('errors.doc_auth.acuant_network_error')],
        exception: exception,
      )
    end
  end
end
