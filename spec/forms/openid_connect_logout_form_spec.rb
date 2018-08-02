require 'rails_helper'

RSpec.describe OpenidConnectLogoutForm do
  let(:state) { SecureRandom.hex }
  let(:code) { SecureRandom.uuid }
  let(:post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/logout' }

  let(:service_provider) { 'urn:gov:gsa:openidconnect:test' }
  let(:identity) do
    create(:identity,
           service_provider: service_provider,
           user: build(:user),
           access_token: SecureRandom.hex,
           session_uuid: SecureRandom.uuid)
  end

  let(:id_token_hint) do
    IdTokenBuilder.new(
      identity: identity,
      code: code,
      custom_expiration: 1.day.from_now.to_i
    ).id_token
  end

  subject(:form) do
    OpenidConnectLogoutForm.new(
      id_token_hint: id_token_hint,
      post_logout_redirect_uri: post_logout_redirect_uri,
      state: state
    )
  end

  describe '#submit' do
    subject(:result) { form.submit }

    context 'with a valid form' do
      it 'deactivates the identity' do
        expect { result }.to change { identity.reload.session_uuid }.to(nil)
      end

      it 'has a redirect URI without errors' do
        expect(URIService.params(result.extra[:redirect_uri])).to_not have_key(:error)
      end

      it 'has a successful response' do
        expect(result).to be_success
      end
    end

    context 'with an invalid form' do
      let(:state) { nil }

      it 'is not successful' do
        expect(result).to_not be_success
      end

      it 'has an error code in the redirect URI' do
        expect(URIService.params(result.extra[:redirect_uri])[:error]).to eq('invalid_request')
      end
    end
  end

  describe '#valid?' do
    subject(:valid?) { form.valid? }

    context 'validating state' do
      context 'when state is missing' do
        let(:state) { nil }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:state]).to be_present
        end
      end

      context 'when state is shorter than the minimum length' do
        let(:state) { 'a' }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:state]).to be_present
        end
      end
    end

    context 'validating id_token_hint' do
      context 'without an id_token_hint' do
        let(:id_token_hint) { nil }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:id_token_hint]).to be_present
        end
      end

      context 'with an id_token_hint that is not a JWT' do
        let(:id_token_hint) { 'asdasd' }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:id_token_hint]).
            to include(t('openid_connect.logout.errors.id_token_hint'))
        end
      end

      context 'with a payload that does not correspond to an identity' do
        let(:id_token_hint) do
          JWT.encode({ sub: '123', aud: '456' }, RequestKeyManager.private_key, 'RS256')
        end

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:id_token_hint]).
            to include(t('openid_connect.logout.errors.id_token_hint'))
        end
      end

      context 'with an expired, but otherwise valid id_token_hint' do
        let(:id_token_hint) do
          IdTokenBuilder.new(
            identity: identity,
            code: code,
            custom_expiration: 5.days.ago.to_i
          ).id_token
        end

        it 'is valid' do
          expect(valid?).to eq(true)
          expect(form.errors[:id_token_hint]).to be_blank
        end
      end
    end

    context 'post_logout_redirect_uri' do
      context 'without a post_logout_redirect_uri' do
        let(:post_logout_redirect_uri) { nil }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:post_logout_redirect_uri]).to be_present
        end
      end

      context 'with URI that does not match what is registered' do
        let(:post_logout_redirect_uri) { 'https://example.com' }

        it 'is not valid' do
          expect(valid?).to eq(false)
          expect(form.errors[:post_logout_redirect_uri]).
            to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
        end
      end
    end
  end
end
