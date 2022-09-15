require 'rails_helper'

RSpec.describe ThreatMetrixJsVerificationJob, type: :job do
  let(:proofing_device_profiling_collecting_enabled) { true }
  let(:threatmetrix_org_id) { 'ABCD1234' }
  let(:threatmetrix_session_id) { 'some-session-id' }

  let(:threatmetrix_signing_key) do
    OpenSSL::PKey::RSA.new 2048
  end

  let(:threatmetrix_signing_cert_expiry) { Time.zone.now + 3600 }

  let(:threatmetrix_signing_certificate) do
    if threatmetrix_signing_key.present?
      name = OpenSSL::X509::Name.parse('/CN=signing')

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 0
      cert.not_before = Time.zone.now
      cert.not_after = threatmetrix_signing_cert_expiry

      cert.public_key = threatmetrix_signing_key.public_key
      cert.subject = name
      cert.issuer = name

      cert.sign threatmetrix_signing_key, 'SHA1'

      cert.to_pem
    end
  end

  let(:js) do
    <<~END
      console.log('Javascript!');
    END
  end

  let(:signature) do
    if threatmetrix_signing_key.present? && threatmetrix_signing_certificate.present?
      sig = threatmetrix_signing_key.sign 'SHA256', js
      sig.unpack1('H*')
    end
  end

  let(:http_response_status) { 200 }

  let(:http_response_body) do
    if signature.nil?
      js
    else
      "#{js}//#{signature}"
    end
  end

  describe '#perform' do
    let(:instance) { described_class.new }

    subject(:perform) do
      instance.perform(
        session_id: threatmetrix_session_id,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).
        and_return(threatmetrix_org_id)
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_js_signing_cert).
        and_return(threatmetrix_signing_certificate)
      allow(IdentityConfig.store).to receive(:proofing_device_profiling_collecting_enabled).
        and_return(proofing_device_profiling_collecting_enabled)

      stub_request(:get, "https://h.online-metrix.net/fp/tags.js?org_id=#{threatmetrix_org_id}&session_id=#{threatmetrix_session_id}").
        to_return(
          status: http_response_status,
          body: http_response_body,
        )
    end

    context 'when collecting is disabled' do
      let(:proofing_device_profiling_collecting_enabled) { false }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'when certificate is not configured' do
      let(:threatmetrix_signing_certificate) { '' }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'when certificate is expired' do
      let(:threatmetrix_signing_cert_expiry) { Time.zone.now - 3600 }
      it 'raises an error' do
        expect { perform }.to raise_error
      end
    end

    context 'when org id is not configured' do
      let(:threatmetrix_org_id) { nil }
      it 'does not run' do
        expect(instance.logger).not_to receive(:info)
        perform
      end
    end

    context 'http request returns empty 204 response' do
      let(:http_response_status) { 204 }
      let(:http_response_body) { '' }

      it 'fails' do
        expect(instance.logger).to receive(:info) do |message|
          expect(JSON.parse(message, symbolize_names: true)).to include(
            name: 'ThreatMetrixJsVerification',
            valid: false,
            http_status: 204,
          )
        end
        perform
      end
    end

    context 'http request succeeds' do
      context 'signature not present' do
        let(:signature) { nil }

        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              js: js,
            )
          end

          perform
        end
      end

      context 'signature not a hex number' do
        let(:signature) { 'not an actual hex number' }
        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              signature: '',
              js: http_response_body,
            )
          end
          perform
        end
      end

      context 'signature present but invalid' do
        let(:signature) { 'bad' }

        it 'logs a failure including JS payload' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              valid: false,
              js: js,
            )
          end

          perform
        end
      end

      context 'signature present and correct' do
        it 'logs on success' do
          expect(instance.logger).to receive(:info) do |message|
            expect(JSON.parse(message, symbolize_names: true)).to include(
              name: 'ThreatMetrixJsVerification',
              session_id: threatmetrix_session_id,
              signature: signature,
              valid: true,
              http_status: 200,
            )
          end

          perform
        end
      end
    end
  end
end
