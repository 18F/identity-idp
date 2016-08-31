require 'rails_helper'

describe Fingerprinter do
  describe '.fingerprint_cert' do
    context 'ssl_cert is nil' do
      it 'returns nil' do
        expect(Fingerprinter.fingerprint_cert(nil)).to be_nil
      end
    end

    context 'ssl_cert is present' do
      it 'returns a hexdigest of the cert' do
        cert =
          "-----BEGIN CERTIFICATE-----\n" \
          "MIIDAjCCAeoCCQDnptBMGdfBIjANBgkqhkiG9w0BAQsFADBCMQswCQYDVQQGEwJV\n" \
          "UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHU2VhdHRsZTEMMAoGA1UE\n" \
          "ChMDMThGMCAXDTE0MTAwODIzMzkzMVoYDzIxMDYwMTEyMjMzOTMxWjBCMQswCQYD\n" \
          "VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHU2VhdHRsZTEM\n" \
          "MAoGA1UEChMDMThGMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1zps\n" \
          "ODzA7AHnls/NaICXSuBjyRbmEmDsoAl6YC/3ljBfG8POZre5wTeSjkPaj/h70ai5\n" \
          "DEWrG3PyEJ0D6QqwNjReChq3AFSSnPLZeRu11N4UVvScJwCpRMs2LD93BBfFy8VU\n" \
          "SQIOsPdrpy9ct31aNzYhi7LF3GBgIwcwq3SLxaF+YYDbbGqHZ8XkjrQlQlRGOPc8\n" \
          "dcKcl0azNqSP4jAp83sw2NsKNPgDpI3PCs3H4C2q0RV/V+A4EIXi/3brAmnwKSOA\n" \
          "JZ2ZAUIjHkv/Y1kk1TzAcy6s/V5f5Mxb4BjXxdAB18umI+EnfHLupV2fScOYY833\n" \
          "AHSpuBiY+b7UfYPU5QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCrjv4rCw3Qhpyv\n" \
          "konOP/Yufxj/SwkaZdanJCnbOvndRk2qO57FQU9qPwUJOu8kws8Xat+A+4ow2hQl\n" \
          "C0b4OlifwrYcnBK/hDOcMOOH/d8na2bzOSg7lkHMOK3luELxPqsnkrszwtqAYs6K\n" \
          "cLk2AEacrkAG0DVfOqYOGtUGUrx5QDYutX2kz24VcZ10so4IfRYI4EJX/tF46lqy\n" \
          "dp6KaRxeVNQo21CGhfzeBSqgd0tRicu9uHzI57nxCLIzSQoLT5c6geCl5LJ7DxS2\n" \
          "kaNiHglqe6GyLbbp3Y5q45xyBGPtJVT6kR6XqK4sEJPRgznbDn2NDx0Ef9mxHdVP\n" \
          "e0sZY2CS\n-----END CERTIFICATE-----\n"

        ssl_cert = OpenSSL::X509::Certificate.new(cert)

        digest = instance_double(OpenSSL::Digest::SHA256)
        expect(OpenSSL::Digest::SHA256).to receive(:new).with(ssl_cert.to_der).and_return(digest)
        expect(digest).to receive(:hexdigest)

        Fingerprinter.fingerprint_cert(ssl_cert)
      end
    end
  end
end
