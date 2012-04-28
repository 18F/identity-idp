require 'openssl'
require 'base64'
require 'time'

module SamlIdp
  module Controller

    attr_accessor :x509_certificate, :secret_key

    def saml_acs_url
      @saml_acs_url
    end

    def x509_certificate
      return @x509_certificate if defined?(@x509_certificate)
      @x509_certificate = SamlIdp::Default::X509_CERTIFICATE
    end

    def secret_key
      return @secret_key if defined?(@secret_key)
      @secret_key = SamlIdp::Default::SECRET_KEY
    end

    protected

      def validate_saml_request(saml_request = params[:SAMLRequest])
        decode_SAMLRequest(saml_request)
      end

      def decode_SAMLRequest(saml_request)
        zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
        text = zstream.inflate(Base64.decode64(saml_request))
        zstream.finish
        zstream.close
        @saml_request_id = text[/ID='(.+?)'/, 1]
        @saml_acs_url = text[/AssertionConsumerServiceURL='(.+?)'/, 1]
      end

      def create_SAMLResponse(nameID, audience_uri, issuer_uri = "#{request.scheme}://#{request.host_with_port}#{request.fullpath}")
        now = Time.now.utc
        response_id, reference_id = UUID.generate, UUID.generate

        assertion = %[<Assertion xmlns="urn:oasis:names:tc:SAML:2.0:assertion" ID="_#{reference_id}" IssueInstant="#{now.iso8601}" Version="2.0"><Issuer>#{issuer_uri}</Issuer><Subject><NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">#{nameID}</NameID><SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer"><SubjectConfirmationData InResponseTo="#{@saml_request_id}" NotOnOrAfter="#{(now+3*60).iso8601}" Recipient="#{@saml_acs_url}"></SubjectConfirmationData></SubjectConfirmation></Subject><Conditions NotBefore="#{(now-5).iso8601}" NotOnOrAfter="#{(now+60*60).iso8601}"><AudienceRestriction><Audience>#{audience_uri}</Audience></AudienceRestriction></Conditions><AttributeStatement><Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"><AttributeValue>#{nameID}</AttributeValue></Attribute></AttributeStatement><AuthnStatement AuthnInstant="#{now.iso8601}" SessionIndex="_#{reference_id}"><AuthnContext><AuthnContextClassRef>urn:federation:authentication:windows</AuthnContextClassRef></AuthnContext></AuthnStatement></Assertion>]

        digest_value = Base64.encode64(OpenSSL::Digest::SHA1.digest(assertion)).chomp

        signed_info = %[<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#"><ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:CanonicalizationMethod><ds:SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"></ds:SignatureMethod><ds:Reference URI="#_#{reference_id}"><ds:Transforms><ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></ds:Transform><ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"></ds:Transform></ds:Transforms><ds:DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"></ds:DigestMethod><ds:DigestValue>#{digest_value}</ds:DigestValue></ds:Reference></ds:SignedInfo>]

        signature_value = sign(signed_info)

        signature = %[<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">#{signed_info}<ds:SignatureValue>#{signature_value}</ds:SignatureValue><KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#"><ds:X509Data><ds:X509Certificate>#{self.x509_certificate}</ds:X509Certificate></ds:X509Data></KeyInfo></ds:Signature>]

        assertion_and_signature = assertion.sub(/Issuer\>\<Subject/, "Issuer>#{signature}<Subject")

        xml = %[<samlp:Response ID="_#{response_id}" Version="2.0" IssueInstant="#{now.iso8601}" Destination="#{@saml_acs_url}" Consent="urn:oasis:names:tc:SAML:2.0:consent:unspecified" InResponseTo="#{@saml_request_id}" xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"><Issuer xmlns="urn:oasis:names:tc:SAML:2.0:assertion">#{issuer_uri}</Issuer><samlp:Status><samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success" /></samlp:Status>#{assertion_and_signature}</samlp:Response>]

        Base64.encode64(xml)
      end

    private

      def sign(data)
        key = OpenSSL::PKey::RSA.new(self.secret_key)
        Base64.encode64(key.sign(OpenSSL::Digest::SHA1.new, data))
      end

  end
end