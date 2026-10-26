require 'rails_helper'

RSpec.describe OpenidConnect::JweEncryptor do
  let(:certs) { ['saml_test_sp'] }
  let(:service_provider) { build(:service_provider, certs:) }
  let(:payload) { { 'sub' => 'a-uuid', 'email' => 'person@example.com' }.to_json }
  let(:private_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }
  let(:other_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
  end

  subject(:jwe) { described_class.encrypt(payload, service_provider:) }

  def header(compact_jwe)
    JSON.parse(Base64.urlsafe_decode64(compact_jwe.split('.').first))
  end

  it 'produces one compact JWE the first registered certificate decrypts to the payload' do
    expect(jwe.split('.').length).to eq(5)
    expect(jwe).not_to include('person@example.com')
    expect(JWE.decrypt(jwe, private_key)).to eq(payload)
  end

  it 'uses RSA-OAEP, A256GCM and DEFLATE, typed as a JWT and naming the key by thumbprint' do
    expect(header(jwe)).to eq(
      'alg' => 'RSA-OAEP',
      'enc' => 'A256GCM',
      'zip' => 'DEF',
      'typ' => 'JWT',
      'kid' => JWT::JWK.new(private_key.public_key).kid,
    )
  end

  it 'cannot be decrypted with another key' do
    expect { JWE.decrypt(jwe, other_private_key) }.to raise_error(OpenSSL::PKey::RSAError)
  end

  context 'with no registered certificate' do
    let(:certs) { [] }

    it 'raises instead of producing anything' do
      expect { jwe }.to raise_error(
        described_class::NoUsableKeyError, /#{Regexp.escape(service_provider.issuer)}/
      )
    end
  end

  context 'with a certificate name that does not exist' do
    let(:certs) { ['i_do_not_exist'] }

    it 'raises instead of producing anything' do
      expect { jwe }.to raise_error(described_class::NoUsableKeyError)
    end
  end
end
