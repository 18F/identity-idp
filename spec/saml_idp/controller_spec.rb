# encoding: utf-8
require 'spec_helper'

class XMLSecurity::SignedDocument

  def validate_doc(base64_cert, soft = true)
    # validate references

    # check for inclusive namespaces
    inclusive_namespaces = extract_inclusive_namespaces

    document = Nokogiri.parse(self.to_s)

    # create a working copy so we don't modify the original
    @working_copy ||= REXML::Document.new(self.to_s).root

    # store and remove signature node
    @sig_element ||= begin
                       element = REXML::XPath.first(@working_copy, "//ds:Signature", {"ds"=>DSIG})
                       element.remove
                     end


    # verify signature
    signed_info_element     = REXML::XPath.first(@sig_element, "//ds:SignedInfo", {"ds"=>DSIG})
    noko_sig_element = document.at_xpath('//ds:Signature', 'ds' => DSIG)
    noko_signed_info_element = noko_sig_element.at_xpath('./ds:SignedInfo', 'ds' => DSIG)
    canon_algorithm = canon_algorithm REXML::XPath.first(@sig_element, '//ds:CanonicalizationMethod', 'ds' => DSIG)
    canon_string = noko_signed_info_element.canonicalize(canon_algorithm)
    noko_sig_element.remove

    # check digests
    REXML::XPath.each(@sig_element, "//ds:Reference", {"ds"=>DSIG}) do |ref|
      uri                           = ref.attributes.get_attribute("URI").value

      hashed_element                = document.at_xpath("//*[@ID='#{uri[1..-1]}']")
      canon_algorithm               = canon_algorithm REXML::XPath.first(ref, '//ds:CanonicalizationMethod', 'ds' => DSIG)
      canon_hashed_element          = hashed_element.canonicalize(canon_algorithm, inclusive_namespaces)

      digest_algorithm              = algorithm(REXML::XPath.first(ref, "//ds:DigestMethod"))

      hash                          = digest_algorithm.digest(canon_hashed_element)
      digest_value                  = Base64.decode64(REXML::XPath.first(ref, "//ds:DigestValue", {"ds"=>DSIG}).text)

      unless digests_match?(hash, digest_value)
        return soft ? false : (raise Onelogin::Saml::ValidationError.new("Digest mismatch"))
      end
    end

    base64_signature        = REXML::XPath.first(@sig_element, "//ds:SignatureValue", {"ds"=>DSIG}).text
    signature               = Base64.decode64(base64_signature)

    # get certificate object
    cert_text               = Base64.decode64(base64_cert)
    cert                    = OpenSSL::X509::Certificate.new(cert_text)

    # signature method
    signature_algorithm     = algorithm(REXML::XPath.first(signed_info_element, "//ds:SignatureMethod", {"ds"=>DSIG}))

    unless cert.public_key.verify(signature_algorithm.new, signature, canon_string)
      return soft ? false : (raise Onelogin::Saml::ValidationError.new("Key validation error"))
    end

    return true
  end
end

describe SamlIdp::Controller do
  include SamlIdp::Controller

  def params
    @params ||= {}
  end

  it "should find the SAML ACS URL" do
    requested_saml_acs_url = "https://example.com/saml/consume"
    params[:SAMLRequest] = make_saml_request(requested_saml_acs_url)
    validate_saml_request
    saml_acs_url.should == requested_saml_acs_url
  end

  context "SAML Responses" do
    before(:each) do
      params[:SAMLRequest] = make_saml_request
      validate_saml_request
    end

    it "should create a SAML Response" do
      saml_response = encode_SAMLResponse("foo@example.com")
      response = Onelogin::Saml::Response.new(saml_response)
      response.name_id.should == "foo@example.com"
      response.issuer.should == "http://example.com"
      response.settings = saml_settings
      response.is_valid?.should be_true
    end

    [:sha1, :sha256, :sha384, :sha512].each do |algorithm_name|
      it "should create a SAML Response using the #{algorithm_name} algorithm" do
        self.algorithm = algorithm_name
        saml_response = encode_SAMLResponse("foo@example.com")
        response = Onelogin::Saml::Response.new(saml_response)
        response.name_id.should == "foo@example.com"
        response.issuer.should == "http://example.com"
        response.settings = saml_settings
        response.is_valid?.should be_true
      end
    end
  end

end
