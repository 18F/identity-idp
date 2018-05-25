require 'rails_helper'
require 'cloudhsm_jwt'

class MockSession; end

describe CloudhsmJwt do
  after(:all) do
    SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, false) }
  end
  let(:jwt_payload) { { key1: 'value1', key2: 'value2' } }
  let(:subject) { CloudhsmJwt.encode(jwt_payload) }

  describe 'encode' do
    context 'when cloudhsm is disabled' do
      before do
        allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('false')
      end

      it 'behaves like before' do
        expect(subject).to eq(JWT.encode(jwt_payload, RequestKeyManager.private_key, 'RS256'))
      end
    end

    context 'when cloudhsm is enabled' do
      before do
        mock_cloudhsm
      end

      it 'raises key not found when the cloudhsm key label is not found' do
        allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(nil)
        stub_const 'SamlIdp::Default::SECRET_KEY', 'secret'
        expect { subject }.to raise_error(RuntimeError, 'CloudHSM key not found for label: key1')
      end

      it 'raises an error if key label is not a string which could happen with a legacy key' do
        allow(Figaro.env).to receive(:cloudhsm_saml_key_label).and_return(nil)
        expect { subject }.to raise_error(RuntimeError, 'Not a CloudHSM key label: nil')
      end

      it 'always calls session logout when opening a session with cloudhsm' do
        allow(MockSession).to receive(:logout).and_raise(RuntimeError, 'logout called')
        expect { subject }.to raise_error(RuntimeError, 'logout called')
      end

      it 'encodes a payload' do
        expect(subject).to be_a(String)
      end
    end
  end

  def mock_cloudhsm
    allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('true')
    SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, true) }
    allow(MockSession).to receive(:login).and_return(true)
    allow(MockSession).to receive(:logout).and_return(true)
    allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(true)
    allow(MockSession).to receive(:sign) do |algorithm, key, input|
      JWT::Algos::Rsa.sign(JWT::Signature::ToSign.new('RS256', input, RequestKeyManager.private_key))
    end
    allow(SamlIdp).to receive_message_chain(:config, :pkcs11, :active_slots, :first, :open).and_yield(MockSession)
    allow(SamlIdp).to receive_message_chain(:config, :cloudhsm_pin).and_return(true)
  end
end
