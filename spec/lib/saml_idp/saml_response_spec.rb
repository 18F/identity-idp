require 'spec_helper'
module SamlIdp
  describe SamlResponse do
    let(:reference_id) { "123" }
    let(:response_id) { "abc" }
    let(:issuer_uri) { "localhost" }
    let(:name_id) { "name" }
    let(:audience_uri) { "localhost/audience" }
    let(:saml_request_id) { "abc123" }
    let(:saml_acs_url) { "localhost/acs" }
    let(:algorithm) { :sha1 }
    let(:secret_key) { Default::SECRET_KEY }
    let(:x509_certificate) { Default::X509_CERTIFICATE }
    subject { described_class.new(reference_id,
                                  response_id,
                                  issuer_uri,
                                  name_id,
                                  audience_uri,
                                  saml_request_id,
                                  saml_acs_url,
                                  algorithm
                                 )
    }

    its(:build) { should be_present }
  end
end
