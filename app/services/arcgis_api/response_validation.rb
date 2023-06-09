module ArcgisApi
  class ResponseValidation < Faraday::Middleware
    def on_complete(env)
      return unless env[:status] == 200 && env.body
      body = env.body.is_a?(String) ? JSON.parse(env.body) : env.body
      return unless body.fetch('error', false)
      handle_api_errors(body)
    rescue => e
      raise e if e.is_a?(Faraday::ServerError)
    end

    def handle_api_errors(response_body)
      # response_body is in this format:
      # {"error"=>{"code"=>400, "message"=>"", "details"=>[""]}}
      error_code = response_body.dig('error', 'code')
      error_message = response_body.dig('error', 'message') || "Received error code #{error_code}"
      # log an error
      raise Faraday::ServerError.new(
        RuntimeError.new(error_message),
        {
          status: error_code,
          body: { details: response_body.dig('error', 'details')&.join(', ') },
        },
      )
    end
  end
end

Faraday::Response.register_middleware(arcgis_response_validation: ArcgisApi::ResponseValidation)
