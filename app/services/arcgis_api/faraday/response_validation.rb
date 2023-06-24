module ArcgisApi::Faraday
  # Faraday middleware to raise exception when response status is 200 but with error in body
  class ResponseValidation < Faraday::Middleware
    # @param [Faraday::Env] env
    def on_complete(env)
      return unless (200..299).cover?(env.status)
      parsed_body = begin
        JSON.parse(env.body)
      rescue
        nil
      end
      return unless parsed_body.is_a?(Hash)
      return unless body.fetch('error', false)

      # response_body is in this format:
      # {"error"=>{"code"=>400, "message"=>"", "details"=>[""]}}
      error_code = response_body.dig('error', 'code')
      error_message = response_body.dig('error', 'message') || "Received error code #{error_code}"
      raise ArcgisApi::Faraday::Error.new(
        "Error received from ArcGIS API: #{error_code}:#{error_message}",
        env[:response],
      )
    end
  end

  class Error < Faraday::Error
  end
end
