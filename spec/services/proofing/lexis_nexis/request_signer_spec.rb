require 'rails_helper'

RSpec.describe Proofing::LexisNexis::RequestSigner do
  let(:message_body) { 'APPLICANT_DATA' }
  let(:path) { '/request/path' }
  let(:timestamp) { Time.zone.now.strftime('%s%L') }
  let(:nonce) { SecureRandom.uuid }
  let(:config) do
    OpenStruct.new(
      base_url: 'https://example.gov',
      hmac_key_id: 'KEY_ID',
      hmac_secret_key: 'SECRET_KEY',
    )
  end

  subject do
    Proofing::LexisNexis::RequestSigner.new(
      config: config,
      message_body: message_body,
      path: path,
    )
  end

  describe 'generating a valid hmac authorization' do
    it 'succeeds' do
      authorization = subject.hmac_authorization(timestamp: timestamp, nonce: nonce)
      regex = %r{
        HMAC-SHA256\s
        keyid=#{config.hmac_key_id},\s
        ts=#{timestamp},\s
        nonce=#{nonce},\s
        bodyHash=(?<hmac>\S+),\s
        signature=(\S+)
      }x

      expect(authorization).to match(regex)

      m = authorization.match(regex)
      hmac = m[:hmac]

      expect(hmac).to eq(OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, message_body))
    end
  end
end
