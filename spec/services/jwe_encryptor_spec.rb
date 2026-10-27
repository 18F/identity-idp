require 'rails_helper'

RSpec.describe JweEncryptor do
  let(:private_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }
  let(:public_key) { private_key.public_key }
  let(:other_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
  end
  let(:payload) { { 'sub' => 'a-uuid', 'email' => 'person@example.com' }.to_json }
  let(:typ) { 'JWT' }

  subject(:jwe) { described_class.encrypt(payload, public_key:, typ:) }

  def header(compact_jwe)
    JSON.parse(Base64.urlsafe_decode64(compact_jwe.split('.').first))
  end

  it 'produces one compact JWE the private key decrypts to the payload' do
    expect(jwe.split('.').length).to eq(5)
    expect(jwe).not_to include('person@example.com')
    expect(JWE.decrypt(jwe, private_key)).to eq(payload)
  end

  it 'uses RSA-OAEP, A256GCM and DEFLATE, carrying the given type and the key thumbprint' do
    expect(header(jwe)).to eq(
      'alg' => 'RSA-OAEP',
      'enc' => 'A256GCM',
      'zip' => 'DEF',
      'typ' => 'JWT',
      'kid' => JWT::JWK.new(public_key).kid,
    )
  end

  context 'with a security event type' do
    let(:typ) { 'secevent+jwe' }

    it 'carries that type in the header' do
      expect(header(jwe)['typ']).to eq('secevent+jwe')
    end
  end

  it 'cannot be decrypted with another key' do
    expect { JWE.decrypt(jwe, other_private_key) }.to raise_error(OpenSSL::PKey::RSAError)
  end

  context 'with no key' do
    let(:public_key) { nil }

    it 'raises instead of producing anything' do
      expect { jwe }.to raise_error(described_class::NoUsableKeyError)
    end
  end

  context 'with a key that is not RSA' do
    let(:public_key) { OpenSSL::PKey::EC.generate('prime256v1') }

    it 'raises instead of producing anything' do
      expect { jwe }.to raise_error(described_class::NoUsableKeyError)
    end
  end
end
