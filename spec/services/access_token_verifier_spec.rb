require 'rails_helper'

RSpec.describe AccessTokenVerifier do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  subject(:verifier) { AccessTokenVerifier.new(http_authorization_header) }
  let(:http_authorization_header) { "Bearer #{access_token}" }

  let(:identity) { build(:service_provider_identity, access_token: SecureRandom.urlsafe_base64) }

  describe '#submit' do
    let(:result) { verifier.submit }

    context 'without an authorization header' do
      let(:http_authorization_header) { nil }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:access_token]).
          to include(t('openid_connect.user_info.errors.no_authorization'))
      end
    end

    context 'with a malformed authorization header' do
      let(:http_authorization_header) { 'BOOOO ABCDEF' }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:access_token]).
          to include(t('openid_connect.user_info.errors.malformed_authorization'))
      end
    end

    context 'with an invalid bearer token' do
      let(:access_token) { 'ABDEF' }

      it 'is not successful' do
        expect(result.success?).to eq(false)
        expect(result.errors[:access_token]).to be_present
      end
    end

    context 'with a valid bearer token' do
      let(:access_token) { identity.access_token }
      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii({}, 1)
      end

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_blank
      end
    end
  end

  describe '#identity' do
    context 'with a valid access_token' do
      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii({}, 1)
      end
      let(:access_token) { identity.access_token }

      it 'returns the identity record' do
        expect(verifier.identity).to eq(identity)
      end
    end

    context 'with a bad access token' do
      let(:access_token) { 'eyyyy' }

      it 'errors' do
        expect(verifier.identity).to be_nil
      end
    end

    context 'with an expired access_token' do
      before { OutOfBandSessionAccessor.new(identity.rails_session_id).destroy }

      let(:access_token) { identity.access_token }

      it 'errors' do
        expect(verifier.identity).to be_nil
      end
    end
  end
end
