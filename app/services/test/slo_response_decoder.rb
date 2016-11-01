module Test
  class SloResponseDecoder
    def initialize(params, settings)
      @params = params
      @settings = settings
    end

    def valid_response?
      response.is_valid? if doc.at_xpath('/samlp:Response', samlp: Saml::XML::Namespaces::PROTOCOL)
    end

    def valid_logout_response?
      return unless doc.at_xpath('/samlp:LogoutResponse', samlp: Saml::XML::Namespaces::PROTOCOL)

      doc.valid_signature?(saml_cert)
    rescue
      false
    end

    def response
      @response ||= OneLogin::RubySaml::Response.new(
        params[:SAMLResponse],
        settings: settings
      )
    end

    private

    attr_reader :params, :settings

    def doc
      @doc ||= Saml::XML::Document.parse(response.document.to_s)
    end
  end
end
