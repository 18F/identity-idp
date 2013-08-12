require 'builder'
require 'saml_idp/algorithmable'
require 'saml_idp/signable'
module SamlIdp
  class AssertionBuilder
    include Algorithmable
    include Signable
    attr_accessor :reference_id
    attr_accessor :issuer_uri
    attr_accessor :name_id
    attr_accessor :audience_uri
    attr_accessor :saml_request_id
    attr_accessor :saml_acs_url
    attr_accessor :raw_algorithm

    delegate :config, to: :SamlIdp

    def initialize(reference_id, issuer_uri, name_id, audience_uri, saml_request_id, saml_acs_url, raw_algorithm)
      self.reference_id = reference_id
      self.issuer_uri = issuer_uri
      self.name_id = name_id
      self.audience_uri = audience_uri
      self.saml_request_id = saml_request_id
      self.saml_acs_url = saml_acs_url
      self.raw_algorithm = raw_algorithm
    end

    def fresh
      builder = Builder::XmlMarkup.new
      builder.Assertion xmlns: Saml::XML::Namespaces::ASSERTION,
        ID: reference_string,
        IssueInstant: now_iso,
        Version: "2.0" do |assertion|
          assertion.Issuer issuer_uri
          sign assertion
          assertion.Subject do |subject|
            subject.NameID name_id, Format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS
            subject.SubjectConfirmation Method: Saml::XML::Namespaces::Methods::BEARER do |confirmation|
              confirmation.SubjectConfirmationData "", InResponseTo: saml_request_id,
                NotOnOrAfter: not_on_or_after_subject,
                Recipient: saml_acs_url
            end
          end
          assertion.Conditions NotBefore: not_before, NotOnOrAfter: not_on_or_after_condition do |conditions|
            conditions.AudienceRestriction do |restriction|
              restriction.Audience audience_uri
            end
          end
          assertion.AttributeStatement do |attr_statement|
            attr_statement.Attribute Name: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" do |attr|
              attr.AttributeValue name_id
            end
          end
          assertion.AuthnStatement AuthnInstant: now_iso, SessionIndex: reference_string do |statement|
            statement.AuthnContext do |context|
              context.AuthnContextClassRef Saml::XML::Namespaces::AuthnContext::ClassRef::PASSWORD
            end
          end
        end
    end
    alias_method :raw, :fresh
    private :fresh

    def reference_string
      "_#{reference_id}"
    end
    private :reference_string

    def now
      @now ||= Time.now.utc
    end
    private :now

    def now_iso
      iso { now }
    end
    private :now_iso

    def not_before
      iso { now - 5 }
    end
    private :not_before

    def not_on_or_after_condition
      iso { now + 60 * 60 }
    end
    private :not_on_or_after_condition

    def not_on_or_after_subject
      iso { now + 3 * 60 }
    end
    private :not_on_or_after_subject

    def iso
      yield.iso8601
    end
    private :iso
  end
end
