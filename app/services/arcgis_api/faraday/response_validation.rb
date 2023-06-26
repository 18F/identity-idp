module ArcgisApi::Faraday
  # Faraday middleware to handle ArcGIS errors
  #
  # The ArcGIS API returns errors that use a 2xx status code,
  # where it's necessary to parse the request body in order to
  # determine whether and what type of error has occurred.
  #
  # The error handling strategy isn't well-documented on a REST
  # API level, only at the level of ArcGIS's SDKs. However the
  # source for esri/arcgis-rest-request suggests what types of
  # errors we can expect.
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
end
