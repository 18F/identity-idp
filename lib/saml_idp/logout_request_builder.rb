require 'saml_idp/logout_builder'
module SamlIdp
  class LogoutRequestBuilder < LogoutBuilder
    attr_accessor :response_id
    attr_accessor :issuer_uri
    attr_accessor :saml_slo_url
    attr_accessor :name_id
    attr_accessor :algorithm

    def initialize(response_id, issuer_uri, saml_slo_url, name_id, algorithm)
      self.response_id = response_id
      self.issuer_uri = issuer_uri
      self.saml_slo_url = saml_slo_url
      self.name_id = name_id
      self.algorithm = algorithm
    end

    def build
      builder = Builder::XmlMarkup.new
      builder.LogoutRequest ID: response_id_string,
        Version: "2.0",
        IssueInstant: now_iso,
        Destination: saml_slo_url,
        "xmlns" => Saml::XML::Namespaces::PROTOCOL do |request|
          request.Issuer issuer_uri, xmlns: Saml::XML::Namespaces::ASSERTION
          sign request
          request.NameID name_id, xmlns: Saml::XML::Namespaces::ASSERTION,
            Format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT
          request.SessionIndex response_id_string
        end
    end
    private :build
  end
end
