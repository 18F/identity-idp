require 'saml_idp/logout_builder'
module SamlIdp
  class LogoutResponseBuilder < LogoutBuilder
    attr_accessor :response_id
    attr_accessor :issuer_uri
    attr_accessor :saml_slo_url
    attr_accessor :saml_request_id
    attr_accessor :signature_opts

    def initialize(response_id, issuer_uri, saml_slo_url, saml_request_id, signature_opts)
      @response_id = response_id
      @issuer_uri = issuer_uri
      @saml_slo_url = saml_slo_url
      @saml_request_id = saml_request_id
      @signature_opts = signature_opts
    end 

    def build
      builder = Builder::XmlMarkup.new
      builder.LogoutResponse ID: response_id_string,
        Version: "2.0",
        IssueInstant: now_iso,
        Destination: saml_slo_url,
        InResponseTo: saml_request_id,
        xmlns: Saml::XML::Namespaces::PROTOCOL do |response|
          response.Issuer issuer_uri, xmlns: Saml::XML::Namespaces::ASSERTION
          sign response
          response.Status xmlns: Saml::XML::Namespaces::PROTOCOL do |status|
            status.StatusCode Value: Saml::XML::Namespaces::Statuses::SUCCESS 
          end 
        end 
    end
    private :build
  end
end
