require 'rails_helper'

class MockSession; end

describe SamlAndOidcSigner do
  describe 'sign' do
    context 'when cloudhsm is disabled' do
      before(:example) do
        allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('false')
      end

      it 'signs the input with RSA256' do
        input = 'ABC123'
        private_key = RequestKeyManager.private_key
        output = JWT::Algos::Rsa.sign(JWT::Signature::ToSign.new('RS256', input, private_key))
        expect(output).to eq(SamlAndOidcSigner.sign('RS256', input, private_key))
      end
    end

    context 'when cloudhsm is enabled' do
      before(:example) do
        mock_cloudhsm
      end

      it 'signs the input with RSA256' do
        input = 'ABC123'
        private_key = RequestKeyManager.private_key
        output = JWT::Algos::Rsa.sign(JWT::Signature::ToSign.new('RS256', input, private_key))
        expect(output).to eq(SamlAndOidcSigner.sign('RS256', input, private_key))
      end
    end
  end

  def mock_cloudhsm
    allow(Figaro.env).to receive(:cloudhsm_enabled).and_return('true')
    SamlIdp.configure { |config| SamlIdpEncryptionConfigurator.configure(config, true) }
    allow(PKCS11).to receive(:open).and_return('true')
    allow_any_instance_of(SamlIdp::Configurator).to receive_message_chain(:pkcs11, :active_slots, :first, :open).and_yield(MockSession)
    allow(MockSession).to receive(:login).and_return(true)
    allow(MockSession).to receive(:logout).and_return(true)
    allow(MockSession).to receive_message_chain(:find_objects, :first).and_return(true)
    allow(MockSession).to receive(:sign) do |algorithm, key, input|
      JWT::Algos::Rsa.sign(JWT::Signature::ToSign.new('RS256', input, RequestKeyManager.private_key))
    end
  end
end
