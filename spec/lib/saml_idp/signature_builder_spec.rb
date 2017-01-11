require 'spec_helper'
module SamlIdp
  describe SignatureBuilder do
    let(:signed) { "jvEbD/rsiPKmoXy7Lhm+FGn88NPGlap4EcPZ2fvjBnk03YESs87FXAIiZZEzN5xq4sBZksUmZe2bV3rrr9sxQNgQawmrrvr66ot7cJiv0ETFArr6kQIZaR5g/V0M4ydxvrfefp6cQVI0hXvmxi830pq0tISiO4J7tyBNX/kvhZk=" }
    let(:raw_info) { "<ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/><ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha256\"/><ds:Reference URI=\"#_abc\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha256\"/><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo>" }
    let(:signed_info) { double raw: raw_info, signed: signed }
    subject { described_class.new(
      signed_info
    ) }

    before do
      allow(Time).to receive_messages now: Time.parse("Jul 31 2013")
    end

    it "builds a legit raw XML file" do
      expect(subject.raw).to eq("<ds:Signature xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/><ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha256\"/><ds:Reference URI=\"#_abc\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha256\"/><ds:DigestValue>em8csGAWynywpe8S4nN64o56/4DosXi2XWMY6RJ6YfA=</ds:DigestValue></ds:Reference></ds:SignedInfo><ds:SignatureValue>jvEbD/rsiPKmoXy7Lhm+FGn88NPGlap4EcPZ2fvjBnk03YESs87FXAIiZZEzN5xq4sBZksUmZe2bV3rrr9sxQNgQawmrrvr66ot7cJiv0ETFArr6kQIZaR5g/V0M4ydxvrfefp6cQVI0hXvmxi830pq0tISiO4J7tyBNX/kvhZk=</ds:SignatureValue><KeyInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><ds:X509Data><ds:X509Certificate>MIIDqzCCAxSgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBhjELMAkGA1UEBhMCQVUxDDAKBgNVBAgTA05TVzEPMA0GA1UEBxMGU3lkbmV5MQwwCgYDVQQKDANQSVQxCTAHBgNVBAsMADEYMBYGA1UEAwwPbGF3cmVuY2VwaXQuY29tMSUwIwYJKoZIhvcNAQkBDBZsYXdyZW5jZS5waXRAZ21haWwuY29tMB4XDTEyMDQyODAyMjIyOFoXDTMyMDQyMzAyMjIyOFowgYYxCzAJBgNVBAYTAkFVMQwwCgYDVQQIEwNOU1cxDzANBgNVBAcTBlN5ZG5leTEMMAoGA1UECgwDUElUMQkwBwYDVQQLDAAxGDAWBgNVBAMMD2xhd3JlbmNlcGl0LmNvbTElMCMGCSqGSIb3DQEJAQwWbGF3cmVuY2UucGl0QGdtYWlsLmNvbTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAuBywPNlC1FopGLYfF96SotiK8Nj6/nW084O4omRMifzy7x955RLEy673q2aiJNB3LvE6Xvkt9cGtxtNoOXw1g2UvHKpldQbr6bOEjLNeDNW7j0ob+JrRvAUOK9CRgdyw5MC6lwqVQQ5C1DnaT/2fSBFjasBFTR24dEpfTy8HfKECAwEAAaOCASUwggEhMAkGA1UdEwQCMAAwCwYDVR0PBAQDAgUgMB0GA1UdDgQWBBQNBGmmt3ytKpcJaBaYNbnyU2xkazATBgNVHSUEDDAKBggrBgEFBQcDATAdBglghkgBhvhCAQ0EEBYOVGVzdCBYNTA5IGNlcnQwgbMGA1UdIwSBqzCBqIAUDQRpprd8rSqXCWgWmDW58lNsZGuhgYykgYkwgYYxCzAJBgNVBAYTAkFVMQwwCgYDVQQIEwNOU1cxDzANBgNVBAcTBlN5ZG5leTEMMAoGA1UECgwDUElUMQkwBwYDVQQLDAAxGDAWBgNVBAMMD2xhd3JlbmNlcGl0LmNvbTElMCMGCSqGSIb3DQEJAQwWbGF3cmVuY2UucGl0QGdtYWlsLmNvbYIBATANBgkqhkiG9w0BAQsFAAOBgQAEcVUPBX7uZmzqZJfy+tUPOT5ImNQj8VE2lerhnFjnGPHmHIqhpzgnwHQujJfs/a309Wm5qwcCaC1eO5cWjcG0x3OjdllsgYDatl5GAumtBx8J3NhWRqNUgitCIkQlxHIwUfgQaCushYgDDL5YbIQa++egCgpIZ+T0Dj5oRew//A==</ds:X509Certificate></ds:X509Data></KeyInfo></ds:Signature>")
    end
  end
end
