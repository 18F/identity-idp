require 'rails_helper'

RSpec.describe OpenidConnect::LogoutController do
  let(:state) { SecureRandom.hex }
  let(:code) { SecureRandom.uuid }
  let(:valid_post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/signout' }
  let(:post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/signout' }

  let(:user) { build(:user) }

  let(:service_provider) do
    create(
      :service_provider, issuer: 'test', redirect_uris: [
        valid_post_logout_redirect_uri,
      ]
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

  shared_examples 'set redirect URL for concurrent session logout' do |req_action, req_method|
    it "#{req_method}: assigns devise session limited failure redirect url" do
      process(req_action, method: req_method)

      expect(request.env['devise_session_limited_failure_redirect_url']).to eq(request.url)
    end
  end

  shared_examples 'when allowing id_token_hint' do |req_action, req_method|
    let(:id_token_hint) { valid_id_token_hint }

    context 'when sending id_token_hint' do
      subject(:action) do
        process req_action,
                method: req_method,
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

          it 'redirects back to the client if server-side redirect is enabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'renders client-side redirect if client-side redirect is enabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'renders JS client-side redirect if client-side JS redirect is enabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side_js')
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'redirects back to the client if UUID set to server-side redirect' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'server_side' })
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'renders client-side redirect if UUID set to to client-side redirect' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'client_side' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'renders JS client-side redirect if UUID set to JS client-side redirect' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'client_side_js' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'respects UUID redirect config when issuer config is also set' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_issuer_override_map).
              and_return({ service_provider.issuer => 'client_side' })
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'client_side_js' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'respects issuer redirect config if UUID config is not set' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_issuer_override_map).
              and_return({ service_provider.issuer => 'client_side_js' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
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
                hash_including(
                  success: false,
                  client_id: service_provider.issuer,
                  client_id_parameter_present: false,
                  id_token_hint_parameter_present: true,
                  errors: errors,
                  error_details: hash_including(*errors.keys),
                  sp_initiated: true,
                  oidc: true,
                  saml_request_valid: nil,
                ),
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
                hash_including(
                  success: false,
                  client_id: nil,
                  client_id_parameter_present: false,
                  id_token_hint_parameter_present: true,
                  errors: hash_including(*errors_keys),
                  error_details: hash_including(*errors_keys),
                  sp_initiated: true,
                  oidc: true,
                  saml_request_valid: nil,
                ),
              )
            action
          end
        end
      end

      context 'user is not signed in' do
        it 'renders server-side redirect if server-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          action

          expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
        end

        it 'redirects back to the client if client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
        end

        it 'redirects back to the client if JS client-side redirect is enabledj' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
        end
      end
    end

    context 'when sending client_id' do
      subject(:action) do
        process req_action,
                method: req_method,
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
            expect(response).to render_template(:confirm_logout)
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
                  saml_request_valid: nil,
                ),
              )

            action
          end
        end
      end

      context 'user is not signed in' do
        it 'redirects back to the client if server-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          action

          expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
        end

        it 'renders client-side redirect if client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
        end

        it 'renders JS client-side redirect if JS client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
        end
      end
    end
  end

  shared_examples 'when rejecting id_token_hint' do |req_action, req_method|
    let(:id_token_hint) { nil }
    subject(:action) do
      process req_action,
              method: req_method,
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

          expect(response).to render_template(:confirm_logout)
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
              hash_including(
                success: false,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: true,
                errors: errors,
                error_details: hash_including(*errors.keys),
                sp_initiated: true,
                oidc: true,
                saml_request_valid: nil,
              ),
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
              hash_including(
                success: false,
                client_id: service_provider.issuer,
                client_id_parameter_present: true,
                id_token_hint_parameter_present: false,
                errors: errors,
                error_details: hash_including(*errors.keys),
                sp_initiated: true,
                oidc: true,
                saml_request_valid: nil,
              ),
            )

          action
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects back to the client if server-side redirect is enabled' do
        expect(controller).to receive(:sign_out)
        allow(IdentityConfig.store).to receive(:openid_connect_redirect).
          and_return('server_side')
        action

        expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
      end

      it 'renders client-side redirect if client-side redirect is enabled' do
        expect(controller).to receive(:sign_out)
        allow(IdentityConfig.store).to receive(:openid_connect_redirect).
          and_return('client_side')
        action

        expect(controller).to render_template('openid_connect/shared/redirect')
        expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
      end

      it 'renders JS client-side redirect if JS client-side redirect is enabled' do
        expect(controller).to receive(:sign_out)
        allow(IdentityConfig.store).to receive(:openid_connect_redirect).
          and_return('client_side_js')
        action

        expect(controller).to render_template('openid_connect/shared/redirect_js')
        expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
      end
    end
  end

  describe 'concurrent session management' do
    it_behaves_like 'set redirect URL for concurrent session logout', :show, 'GET'
    it_behaves_like 'set redirect URL for concurrent session logout', :create, 'POST'
  end

  context 'when accepting id_token_hint and client_id' do
    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(false)
    end

    describe '#logout[GET]' do
      it_behaves_like 'when allowing id_token_hint', :show, 'GET'
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
          let(:user) { create(:user) }
          before { stub_sign_in(user) }

          it 'destroys the session and redirects to client if server-side redirect is enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'destroys session and renders client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'destroys session and renders JS client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side_js')
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'destroys the session and redirects to client if UUID set to server-side redirect' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'server_side' })
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'destroys session and renders client-side redirect if UUID is set to client-side' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'client_side' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'destroy session and render JS client-side redirect if UUID set to JS client-side' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
              and_return({ user.uuid => 'client_side_js' })
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end
        end

        context 'user is not signed in' do
          it 'redirects to new session path' do
            expect(controller).to_not receive(:sign_out)
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
          it 'destroys the session and redirects if client-side redirect is disabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'destroys the session and renders client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'destroys the session and renders JS client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side_js')
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end
        end

        context 'user is not signed in' do
          it 'redirects to new session path' do
            expect(controller).to_not receive(:sign_out)
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

    describe '#logout[GET]' do
      it_behaves_like 'when rejecting id_token_hint', :show, 'GET'
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
          it 'destroys session and redirects to client if server-side redirect is enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            action

            expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
          end

          it 'destroys the session and renders client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')
            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
          end

          it 'destroys the session and renders JS client-side redirect if enabled' do
            expect(controller).to receive(:sign_out)
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side_js')
            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(post_logout_redirect_uri)
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
