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

  def self_signed_pem(bits:)
    key = OpenSSL::PKey::RSA.new(bits)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=short-key')
    cert.public_key = key.public_key
    cert.not_before = 1.minute.ago
    cert.not_after = 1.hour.from_now
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    cert.to_pem
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

  context 'when the payload is not a JWT' do
    subject(:jwe) do
      described_class.encrypt(payload, service_provider:, typ: nil, cty: 'image/jpeg')
    end

    it 'names the payload media type as cty and carries no typ' do
      header = JSON.parse(Base64.urlsafe_decode64(jwe.split('.').first))

      expect(header).to include('cty' => 'image/jpeg', 'alg' => 'RSA-OAEP', 'enc' => 'A256GCM')
      expect(header).not_to have_key('typ')
    end
  end

  context 'when the first registered certificate has expired' do
    let(:certs) { ['saml_test_sp2', 'saml_test_sp'] }

    it 'skips it and encrypts to the next currently valid certificate' do
      expect(header(jwe)['kid']).to eq(JWT::JWK.new(private_key.public_key).kid)
      expect(JWE.decrypt(jwe, private_key)).to eq(payload)
    end
  end

  context 'when the only registered certificate has expired' do
    let(:certs) { ['saml_test_sp2'] }

    it 'raises instead of sealing to a key that is no longer valid' do
      expect { jwe }.to raise_error(described_class::NoUsableKeyError)
    end
  end

  context 'when the only registered certificate carries a short RSA key' do
    let(:certs) { [self_signed_pem(bits: 1024)] }

    it 'raises instead of sealing to a weak key' do
      expect { jwe }.to raise_error(described_class::NoUsableKeyError)
    end
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
