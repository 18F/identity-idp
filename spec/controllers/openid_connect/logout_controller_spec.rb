require 'rails_helper'

RSpec.describe OpenidConnect::LogoutController do
  let(:state) { SecureRandom.hex }
  let(:code) { SecureRandom.uuid }
  let(:valid_post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/signout' }
  let(:post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/signout' }

  let(:user) { build(:user) }

  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'test',
      redirect_uris: [
        valid_post_logout_redirect_uri,
      ],
    )
  end
  let(:identity) do
    create(
      :service_provider_identity,
      service_provider: service_provider.issuer,
      user: user,
      access_token: SecureRandom.hex,
      session_uuid: SecureRandom.uuid,
    )
  end

  let(:valid_id_token_hint) do
    IdTokenBuilder.new(
      identity: identity,
      code: code,
      custom_expiration: 1.day.from_now.to_i,
    ).id_token
  end

  context 'when accepting id_token_hint and client_id' do
    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(false)
    end

    describe '#index' do
      let(:id_token_hint) { valid_id_token_hint }

      context 'when sending id_token_hint' do
        subject(:action) do
          get :index,
              params: {
                id_token_hint: id_token_hint,
                post_logout_redirect_uri: post_logout_redirect_uri,
                state: state,
              }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }

          context 'with valid params' do
            it 'destroys the session' do
              expect(controller).to receive(:sign_out).and_call_original

              action
            end

            it 'redirects back to the client' do
              action

              expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
            end

            it 'tracks events' do
              stub_analytics
              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Requested',
                  hash_including(
                    success: true,
                    client_id: service_provider.issuer,
                    client_id_parameter_present: false,
                    id_token_hint_parameter_present: true,
                    errors: {},
                    sp_initiated: true,
                    oidc: true,
                  ),
                )
              expect(@analytics).to receive(:track_event).
                with(
                  'Logout Initiated',
                  hash_including(
                    success: true,
                    client_id: service_provider.issuer,
                    client_id_parameter_present: false,
                    id_token_hint_parameter_present: true,
                    errors: {},
                    sp_initiated: true,
                    oidc: true,
                  ),
                )

              stub_attempts_tracker
              expect(@irs_attempts_api_tracker).to receive(:logout_initiated).
                with(
                  success: true,
                )
              action
            end
          end

          context 'with a bad redirect URI' do
            let(:post_logout_redirect_uri) { 'https://example.com' }

            it 'renders an error page' do
              action

              expect(response).to render_template(:error)
            end

            it 'does not destroy the session' do
              expect(controller).to_not receive(:sign_out)

              action
            end

            it 'tracks events' do
              stub_analytics

              errors = {
                redirect_uri: [t('openid_connect.authorization.errors.redirect_uri_no_match')],
              }
              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Requested',
                  success: false,
                  client_id: service_provider.issuer,
                  client_id_parameter_present: false,
                  id_token_hint_parameter_present: true,
                  errors: errors,
                  error_details: hash_including(*errors.keys),
                  sp_initiated: true,
                  oidc: true,
                  method: nil,
                  saml_request_valid: nil,
                )

              action
            end
          end

          context 'with a bad id_token_hint' do
            let(:id_token_hint) { 'abc123' }
            it 'tracks events' do
              stub_analytics
              errors_keys = [:id_token_hint]

              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Requested',
                  success: false,
                  client_id: nil,
                  client_id_parameter_present: false,
                  id_token_hint_parameter_present: true,
                  errors: hash_including(*errors_keys),
                  error_details: hash_including(*errors_keys),
                  sp_initiated: true,
                  oidc: true,
                  method: nil,
                  saml_request_valid: nil,
                )

              action
            end
          end
        end

        context 'user is not signed in' do
          it 'redirects back with an error' do
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end
        end
      end

      context 'when sending client_id' do
        subject(:action) do
          get :index,
              params: {
                client_id: service_provider.issuer,
                post_logout_redirect_uri: post_logout_redirect_uri,
                state: state,
              }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }

          context 'with valid params' do
            render_views

            it 'renders logout confirmation page' do
              stub_analytics
              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Requested',
                  hash_including(
                    success: true,
                    client_id: service_provider.issuer,
                    client_id_parameter_present: true,
                    id_token_hint_parameter_present: false,
                    errors: {},
                    sp_initiated: true,
                    oidc: true,
                  ),
                )
              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Page Visited',
                  hash_including(
                    success: true,
                    client_id: service_provider.issuer,
                    client_id_parameter_present: true,
                    id_token_hint_parameter_present: false,
                    errors: {},
                    sp_initiated: true,
                    oidc: true,
                  ),
                )

              action
              expect(response).to render_template(:index)
              expect(response.body).to include service_provider.friendly_name
            end
          end

          context 'with a bad redirect URI' do
            let(:post_logout_redirect_uri) { 'https://example.com' }

            it 'renders an error page' do
              action

              expect(response).to render_template(:error)
            end

            it 'does not destroy the session' do
              expect(controller).to_not receive(:sign_out)

              action
            end

            it 'tracks events' do
              stub_analytics

              errors = {
                redirect_uri: [t('openid_connect.authorization.errors.redirect_uri_no_match')],
              }
              expect(@analytics).to receive(:track_event).
                with(
                  'OIDC Logout Requested',
                  hash_including(
                    success: false,
                    client_id: service_provider.issuer,
                    client_id_parameter_present: true,
                    id_token_hint_parameter_present: false,
                    errors: errors,
                    error_details: hash_including(*errors.keys),
                    sp_initiated: true,
                    oidc: true,
                    method: nil,
                    saml_request_valid: nil,
                  ),
                )

              action
            end
          end
        end

        context 'user is not signed in' do
          it 'redirects back to client' do
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end
        end
      end
    end

    describe '#delete' do
      context 'when sending client_id' do
        subject(:action) do
          delete :delete,
                 params: {
                   client_id: service_provider.issuer,
                   post_logout_redirect_uri: post_logout_redirect_uri,
                   state: state,
                 }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }
          it 'destroys the session' do
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end
        end

        context 'user is not signed in' do
          it 'destroys the session' do
            action

            expect(response).to redirect_to(new_user_session_path)
          end
        end
      end

      context 'when sending id_token_hint' do
        let(:id_token_hint) { valid_id_token_hint }
        subject(:action) do
          delete :delete,
                 params: {
                   id_token_hint: id_token_hint,
                   post_logout_redirect_uri: post_logout_redirect_uri,
                   state: state,
                 }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }
          it 'destroys the session' do
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end
        end

        context 'user is not signed in' do
          it 'destroys the session' do
            action

            expect(response).to redirect_to(new_user_session_path)
          end
        end
      end
    end
  end

  context 'when rejecting id_token_hint' do
    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(true)
    end

    describe '#index' do
      let(:id_token_hint) { nil }
      subject(:action) do
        get :index,
            params: {
              client_id: service_provider.issuer,
              id_token_hint: id_token_hint,
              post_logout_redirect_uri: post_logout_redirect_uri,
              state: state,
            }
      end

      context 'user is signed in' do
        before { stub_sign_in(user) }

        context 'with valid params' do
          it 'renders logout confirmation page' do
            action

            expect(response).to render_template(:index)
          end

          it 'tracks events' do
            stub_analytics
            expect(@analytics).to receive(:track_event).
              with(
                'OIDC Logout Requested',
                hash_including(
                  success: true,
                  client_id: service_provider.issuer,
                  client_id_parameter_present: true,
                  id_token_hint_parameter_present: false,
                  errors: {},
                  sp_initiated: true,
                  oidc: true,
                ),
              )

            expect(@analytics).to receive(:track_event).
              with(
                'OIDC Logout Page Visited',
                hash_including(
                  success: true,
                  client_id: service_provider.issuer,
                  client_id_parameter_present: true,
                  id_token_hint_parameter_present: false,
                  errors: {},
                  sp_initiated: true,
                  oidc: true,
                ),
              )

            action
          end
        end

        context 'with an id_token_hint' do
          let(:id_token_hint) { valid_id_token_hint }

          it 'renders an error page' do
            action

            expect(response).to render_template(:error)
          end

          it 'does not destroy the session' do
            expect(controller).to_not receive(:sign_out)

            action
          end

          it 'tracks events' do
            stub_analytics

            errors = {
              id_token_hint: [t('openid_connect.logout.errors.id_token_hint_present')],
            }
            expect(@analytics).to receive(:track_event).
              with(
                'OIDC Logout Requested',
                success: false,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: true,
                errors: errors,
                error_details: hash_including(*errors.keys),
                sp_initiated: true,
                oidc: true,
                method: nil,
                saml_request_valid: nil,
              )

            action
          end
        end

        context 'with a bad redirect URI' do
          let(:post_logout_redirect_uri) { 'https://example.com' }

          it 'renders an error page' do
            action

            expect(response).to render_template(:error)
          end

          it 'does not destroy the session' do
            expect(controller).to_not receive(:sign_out)

            action
          end

          it 'tracks events' do
            stub_analytics

            errors = {
              redirect_uri: [t('openid_connect.authorization.errors.redirect_uri_no_match')],
            }
            expect(@analytics).to receive(:track_event).
              with(
                'OIDC Logout Requested',
                success: false,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: false,
                errors: errors,
                error_details: hash_including(*errors.keys),
                sp_initiated: true,
                oidc: true,
                method: nil,
                saml_request_valid: nil,
              )

            action
          end
        end
      end

      context 'user is not signed in' do
        it 'redirects back to client' do
          action

          expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
        end
      end
    end

    describe '#delete' do
      context 'when sending client_id' do
        subject(:action) do
          delete :delete,
                 params: {
                   client_id: service_provider.issuer,
                   post_logout_redirect_uri: post_logout_redirect_uri,
                   state: state,
                 }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }
          it 'destroys the session' do
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'tracks events' do
            stub_analytics

            expect(@analytics).to receive(:track_event).
              with(
                'OIDC Logout Submitted',
                success: true,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: false,
                errors: {},
                error_details: nil,
                sp_initiated: true,
                oidc: true,
                method: nil,
                saml_request_valid: nil,
              )
            expect(@analytics).to receive(:track_event).
              with(
                'Logout Initiated',
                success: true,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: false,
                errors: {},
                error_details: nil,
                sp_initiated: true,
                oidc: true,
                method: nil,
                saml_request_valid: nil,
              )
            stub_attempts_tracker
            expect(@irs_attempts_api_tracker).to receive(:logout_initiated).
              with(
                success: true,
              )

            action
          end
        end

        context 'user is not signed in' do
          it 'destroys the session' do
            action

            expect(response).to redirect_to(new_user_session_path)
          end
        end
      end

      context 'when sending id_token_hint' do
        let(:id_token_hint) { valid_id_token_hint }
        subject(:action) do
          delete :delete,
                 params: {
                   id_token_hint: id_token_hint,
                   post_logout_redirect_uri: post_logout_redirect_uri,
                   state: state,
                 }
        end

        context 'user is signed in' do
          before { stub_sign_in(user) }
          it 'destroys the session' do
            action

            expect(response).to render_template(:error)
          end
        end

        context 'user is not signed in' do
          it 'destroys the session' do
            action

            expect(response).to redirect_to(new_user_session_path)
          end
        end
      end
    end
  end

  def add_sp_session_request_url
    params = {
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      client_id: service_provider.issuer,
      nonce: SecureRandom.hex,
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      response_type: 'code',
      scope: 'openid profile',
      state: SecureRandom.hex,
    }
    session[:sp] = {
      request_url: URI.parse(
        "http://#{IdentityConfig.store.domain_name}?#{URI.encode_www_form(params)}",
      ).to_s,
    }
  end
end
