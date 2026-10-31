require 'rails_helper'

RSpec.describe SiteKeys::Sealer do
  let(:recipient_pair) { SiteKeys::KeyPair.generate }
  let(:recipient) { recipient_pair.public_key }
  let(:client_id) { 'urn:gov:gsa:openidconnect:sp:mybenefits' }
  let(:payload) do
    { 'kty' => 'EC', 'crv' => 'P-256', 'x' => 'xx', 'y' => 'yy', 'd' => 'dd' }.to_json
  end

  # Opens a compact JWE the way a recipient page would: ECDH-ES to the epk, the Concat KDF, then
  # AES-256-GCM with the protected header as the additional authenticated data. Written out from
  # the standards rather than reusing the sealer, so it pins the wire format.
  def open_sealed(sealed, recipient_key:, client_id:)
    header_b64, _cek, iv_b64, ct_b64, tag_b64 = sealed.split('.')
    header = JSON.parse(Base64.urlsafe_decode64(header_b64))
    epk = JWT::JWK.import(header['epk'].transform_keys(&:to_sym)).verify_key
    shared = recipient_key.dh_compute_key(epk.public_key)
    other = [header['enc'].bytesize].pack('N') + header['enc'] +
            [0].pack('N') +
            [client_id.bytesize].pack('N') + client_id +
            [256].pack('N')
    cek = OpenSSL::Digest::SHA256.digest([1].pack('N') + shared + other)[0, 32]
    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = cek
    cipher.iv = Base64.urlsafe_decode64(iv_b64)
    cipher.auth_tag = Base64.urlsafe_decode64(tag_b64)
    cipher.auth_data = header_b64
    [header, cipher.update(Base64.urlsafe_decode64(ct_b64)) + cipher.final]
  end

  subject(:sealed) do
    described_class.seal(payload, recipient:, client_id:, cty: 'jwk+json')
  end

  it 'produces a five-part compact JWE with an empty encrypted-key part' do
    parts = sealed.split('.', -1)
    expect(parts.length).to eq(5)
    expect(parts[1]).to eq('')
  end

  it 'names the algorithm, content type and recipient key in the protected header' do
    header, = open_sealed(sealed, recipient_key: recipient_pair.key, client_id:)
    expect(header).to include(
      'alg' => 'ECDH-ES', 'enc' => 'A256GCM', 'cty' => 'jwk+json',
      'kid' => DpopProofForm.thumbprint(recipient)
    )
    expect(header['apv']).to eq(Base64.urlsafe_encode64(client_id, padding: false))
  end

  it 'the recipient recovers the exact payload' do
    _header, plaintext = open_sealed(sealed, recipient_key: recipient_pair.key, client_id:)
    expect(plaintext).to eq(payload)
  end

  it 'cannot be opened under another client identifier' do
    _header, = open_sealed(sealed, recipient_key: recipient_pair.key, client_id:)
    expect do
      open_sealed(sealed, recipient_key: recipient_pair.key, client_id: 'urn:someone:else')
    end.to raise_error(OpenSSL::Cipher::CipherError)
  end

  it 'cannot be opened by another key pair' do
    expect do
      open_sealed(sealed, recipient_key: SiteKeys::KeyPair.generate.key, client_id:)
    end.to raise_error(OpenSSL::Cipher::CipherError)
  end

  it 'uses a fresh ephemeral key each time' do
    first = described_class.seal(payload, recipient:, client_id:, cty: 'jwk+json')
    second = described_class.seal(payload, recipient:, client_id:, cty: 'jwk+json')
    epk = ->(s) { JSON.parse(Base64.urlsafe_decode64(s.split('.').first))['epk'] }
    expect(epk.call(first)).not_to eq(epk.call(second))
  end
end
