require 'rails_helper'

RSpec.describe AccessTokenVerifier do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  subject(:verifier) { AccessTokenVerifier.new(http_authorization_header) }
  let(:http_authorization_header) { "Bearer #{access_token}" }

  let(:identity) do
    build(
      :service_provider_identity,
      rails_session_id: '123',
      access_token: SecureRandom.urlsafe_base64,
    )
  end

  describe '#submit' do
    let(:result) { verifier.submit }

    context 'without an authorization header' do
      let(:http_authorization_header) { nil }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token])
          .to include(t('openid_connect.user_info.errors.no_authorization'))
        expect(result_identity).to be_nil
      end
    end

    context 'with a malformed authorization header' do
      let(:http_authorization_header) { 'BOOOO ABCDEF' }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token])
          .to include(t('openid_connect.user_info.errors.malformed_authorization'))
        expect(result_identity).to be_nil
      end
    end

    context 'with an invalid bearer token' do
      let(:access_token) { 'ABDEF' }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token]).to be_present
        expect(result_identity).to be_nil
      end
    end

    context 'with a bearer token for an expired session' do
      before { OutOfBandSessionAccessor.new(identity.rails_session_id).destroy }

      let(:access_token) { identity.access_token }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token]).to be_present
        expect(result_identity).to be_nil
      end
    end

    context 'with a valid bearer token' do
      let(:access_token) { identity.access_token }
      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123,
          pii: {},
          expiration: 5,
        )
      end

      it 'is successful' do
        response, result_identity = result

        expect(response.success?).to eq(true)
        expect(response.errors).to be_blank
        expect(result_identity).to eq(identity)
      end
    end
  end
end
