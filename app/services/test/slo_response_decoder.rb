module Test
  class SloResponseDecoder
    def initialize(params, settings)
      @params = params
      @settings = settings
    end

    def response
      @response ||= OneLogin::RubySaml::Response.new(
        params[:SAMLResponse],
        settings: settings,
      )
    end

    private

    attr_reader :params, :settings

    def doc
      @doc ||= Saml::XML::Document.parse(response.document.to_s)
    end
  end
end
