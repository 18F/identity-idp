require 'rails_helper'

RSpec.describe OpenidConnectLogoutForm do
  let(:state) { SecureRandom.hex }
  let(:code) { SecureRandom.uuid }
  let(:post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/signout' }

  let(:service_provider) { 'urn:gov:gsa:openidconnect:test' }
  let(:user) { create(:user) }
  let(:identity) do
    create(
      :service_provider_identity,
      service_provider: service_provider,
      user: user,
      access_token: SecureRandom.hex,
      session_uuid: SecureRandom.uuid,
    )
  end

  let(:client_id) { service_provider }

  let(:valid_id_token_hint) do
    IdTokenBuilder.new(
      identity: identity,
      code: code,
      custom_expiration: 1.day.from_now.to_i,
    ).id_token
  end

  subject(:form) do
    OpenidConnectLogoutForm.new(
      current_user: current_user,
      params: {
        client_id: client_id,
        id_token_hint: id_token_hint,
        post_logout_redirect_uri: post_logout_redirect_uri,
        state: state,
      },
    )
  end

  context 'when we accept id_token_hint' do
    let(:id_token_hint) { valid_id_token_hint }
    let(:client_id) { nil }
    let(:current_user) { nil }

    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(false)
    end

    describe '#submit' do
      subject(:result) { form.submit }

      context 'with a valid form' do
        it 'deactivates the identity' do
          expect { result }.to change { identity.reload.session_uuid }.to(nil)
        end

        it 'has a redirect URI without errors' do
          expect(UriService.params(result.extra[:redirect_uri])).to_not have_key(:error)
        end

        it 'has a successful response' do
          expect(result).to be_success
        end

        context 'with missing state' do
          let(:state) { nil }

          it 'deactivates the identity' do
            expect { result }.to change { identity.reload.session_uuid }.to(nil)
          end

          it 'has a redirect URI without errors' do
            expect(UriService.params(result.extra[:redirect_uri])).to_not have_key(:error)
          end

          it 'has a successful response' do
            expect(result).to be_success
          end
        end
      end

      context 'with an invalid form' do
        let(:state) { 'ab' }

        it 'is not successful' do
          expect(result).to_not be_success
        end

        it 'has an error code in the redirect URI' do
          expect(UriService.params(result.extra[:redirect_uri])[:error]).to eq('invalid_request')
        end
      end
    end

    describe '#valid?' do
      subject(:valid?) { form.valid? }

      context 'validating state' do
        context 'when state is missing' do
          let(:state) { nil }

          it 'is valid' do
            expect(valid?).to eq(true)
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

          context 'when accepting client_id' do
            before do
              allow(IdentityConfig.store).to receive(:accept_client_id_in_oidc_logout).
                and_return(true)
            end

            context 'without client_id' do
              let(:client_id) { nil }

              it 'is not valid' do
                expect(valid?).to eq(false)
                expect(form.errors[:base]).to be_present
              end
            end

            context 'with a valid client_id' do
              let(:client_id) { service_provider }

              it 'is valid' do
                expect(valid?).to eq(true)
              end
            end
          end

          context 'when not accepting client_id' do
            before do
              allow(IdentityConfig.store).to receive(:accept_client_id_in_oidc_logout).
                and_return(false)
            end

            context 'without client_id' do
              let(:client_id) { nil }

              it 'is not valid' do
                expect(valid?).to eq(false)
                expect(form.errors[:id_token_hint]).to be_present
              end
            end

            context 'with a valid client_id' do
              let(:client_id) { service_provider }

              it 'is not valid' do
                expect(valid?).to eq(false)
                expect(form.errors[:client_id]).to be_present
              end
            end
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
            JWT.encode({ sub: '123', aud: '456' }, AppArtifacts.store.oidc_private_key, 'RS256')
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
              custom_expiration: 5.days.ago.to_i,
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
            expect(form.errors[:redirect_uri]).to be_present
          end
        end

        context 'with URI that does not match what is registered' do
          let(:post_logout_redirect_uri) { 'https://example.com' }

          it 'is not valid' do
            expect(valid?).to eq(false)
            expect(form.errors[:redirect_uri]).
              to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
          end
        end
      end
    end
  end

  context 'when we reject id_token_hint' do
    let(:id_token_hint) { nil }
    let(:current_user) { nil }

    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(true)
    end

    describe '#submit' do
      subject(:result) { form.submit }

      context 'with a valid form' do
        context 'with a current user' do
          let(:current_user) { user }

          it 'deactivates the identity' do
            expect { result }.to change { identity.reload.session_uuid }.to(nil)
          end
        end

        it 'has a redirect URI without errors' do
          expect(UriService.params(result.extra[:redirect_uri])).to_not have_key(:error)
        end

        it 'has a successful response' do
          expect(result).to be_success
        end

        context 'without state' do
          let(:state) { nil }

          it 'has a redirect URI without errors' do
            expect(UriService.params(result.extra[:redirect_uri])).to_not have_key(:error)
          end

          it 'has a successful response' do
            expect(result).to be_success
          end
        end
      end

      context 'with an invalid form' do
        let(:state) { 'ab' }

        it 'is not successful' do
          expect(result).to_not be_success
        end

        it 'has an error code in the redirect URI' do
          expect(UriService.params(result.extra[:redirect_uri])[:error]).to eq('invalid_request')
        end
      end
    end

    describe '#valid?' do
      subject(:valid?) { form.valid? }

      context 'validating state' do
        context 'when state is missing' do
          let(:state) { nil }

          it 'is valid' do
            expect(valid?).to eq(true)
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

          it 'is valid' do
            expect(valid?).to eq(true)
            expect(form.errors[:id_token_hint]).not_to be_present
          end
        end

        context 'with an id_token_hint' do
          let(:id_token_hint) { valid_id_token_hint }

          it 'is not valid' do
            expect(valid?).to eq(false)
            expect(form.errors[:id_token_hint]).
              to include(t('openid_connect.logout.errors.id_token_hint_present'))
          end
        end
      end

      context 'post_logout_redirect_uri' do
        context 'without a post_logout_redirect_uri' do
          let(:post_logout_redirect_uri) { nil }

          it 'is not valid' do
            expect(valid?).to eq(false)
            expect(form.errors[:redirect_uri]).to be_present
          end
        end

        context 'with URI that does not match what is registered' do
          let(:post_logout_redirect_uri) { 'https://example.com' }

          it 'is not valid' do
            expect(valid?).to eq(false)
            expect(form.errors[:redirect_uri]).
              to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
          end
        end

        context 'when no client_id passed' do
          let(:client_id) { nil }

          it 'does not include error about redirect_uri' do
            expect(valid?).to eq(false)
            expect(form.errors[:redirect_uri]).
              not_to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
          end

          it 'is not valid' do
            expect(valid?).to eq(false)
            expect(form.errors[:client_id]).
              to include(t('openid_connect.logout.errors.client_id_missing'))
          end
        end
      end
    end
  end
end
