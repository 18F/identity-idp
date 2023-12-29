# rubocop:disable Layout/LineLength
require 'rails_helper'

RSpec.describe OpenidConnect::AuthorizationController do
  include WebAuthnHelper
  before do
    # All the tests here were written prior to the interstitial
    # authorization confirmation page so let's force the system
    # to skip past that page
    allow(controller).to receive(:auth_count).and_return(2)
  end

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:service_provider) { build(:service_provider, issuer: client_id) }
  let(:prompt) { 'select_account' }
  let(:params) do
    {
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      client_id: client_id,
      nonce: SecureRandom.hex,
      prompt: prompt,
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      response_type: 'code',
      scope: 'openid profile',
      state: SecureRandom.hex,
    }
  end

  describe '#index' do
    subject(:action) { get :index, params: params }

    context 'with prompt=login' do
      let(:prompt) { 'login' }

      it 'does not log user out when switching languages after authentication' do
        user = create(:user, :with_phone)
        action
        sign_in_as_user(user)
        get :index, params: params.merge(locale: 'es')
        expect(controller.current_user).to eq(user)
      end
    end

    context 'user is signed in' do
      let(:user) { create(:user, :fully_registered) }
      before do
        stub_sign_in user
      end

      context 'with valid params' do
        it 'redirects back to the client app with a code if server-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          IdentityLinker.new(user, service_provider).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = UriService.params(response.location)

          expect(redirect_params[:code]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders a client-side redirect back to the client app with a code if it is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          IdentityLinker.new(user, service_provider).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:code]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders a JS client-side redirect back to the client app with a code if it is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          IdentityLinker.new(user, service_provider).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:code]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'tracks IAL1 authentication event' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with('OpenID Connect: authorization request',
                 success: true,
                 client_id: client_id,
                 prompt: 'select_account',
                 referer: nil,
                 allow_prompt_login: true,
                 errors: {},
                 unauthorized_scope: true,
                 user_fully_authenticated: true,
                 acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
                 code_challenge_present: false,
                 service_provider_pkce: nil,
                 scope: 'openid')
          expect(@analytics).to receive(:track_event).
            with('OpenID Connect: authorization request handoff',
                 success: true,
                 client_id: client_id,
                 user_sp_authorized: true,
                 code_digest: kind_of(String))
          expect(@analytics).to receive(:track_event).
            with(
              'SP redirect initiated',
              ial: 1,
              billed_ial: 1,
            )

          IdentityLinker.new(user, service_provider).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])

          action

          sp_return_log = SpReturnLog.find_by(issuer: client_id)
          expect(sp_return_log.ial).to eq(1)
        end

        context 'with ial2 requested' do
          before { params[:acr_values] = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

          context 'account is already verified' do
            let(:user) do
              create(
                :profile, :active, :verified, proofing_components: { liveness_check: true }
              ).user
            end

            it 'redirects to the redirect_uri immediately when pii is unlocked if client-side redirect is disabled' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('server_side')
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
            end

            it 'renders a client-side redirect back to the client app immediately if it is enabled' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('client_side')
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(controller).to render_template('openid_connect/shared/redirect')
              expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
            end

            it 'renders a JS client-side redirect back to the client app immediately if it is enabled' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('client_side_js')
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(controller).to render_template('openid_connect/shared/redirect_js')
              expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
            end

            it 'redirects back to the client app immediately if UUID is overridden to server-side redirect' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('client_side')
              allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
                and_return({ user.uuid => 'server_side' })
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
            end

            it 'renders a client-side redirect back to the client app immediately if UUID is overridden to client-side redirect' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('server_side')
              allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
                and_return({ user.uuid => 'client_side' })
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(controller).to render_template('openid_connect/shared/redirect')
              expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
            end

            it 'renders a JS client-side redirect back to the client app immediately if UUID is overridden to JS client-side redirect' do
              allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                and_return('server_side')
              allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
                and_return({ user.uuid => 'client_side_js' })
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(controller).to render_template('openid_connect/shared/redirect_js')
              expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
            end

            it 'redirects to the password capture url when pii is locked' do
              IdentityLinker.new(user, service_provider).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(true)
              action

              expect(response).to redirect_to(capture_password_url)
            end

            it 'tracks IAL2 authentication event' do
              stub_analytics
              expect(@analytics).to receive(:track_event).
                with('OpenID Connect: authorization request',
                     success: true,
                     client_id: client_id,
                     prompt: 'select_account',
                     referer: nil,
                     allow_prompt_login: true,
                     errors: {},
                     unauthorized_scope: false,
                     user_fully_authenticated: true,
                     acr_values: 'http://idmanagement.gov/ns/assurance/ial/2',
                     code_challenge_present: false,
                     service_provider_pkce: nil,
                     scope: 'openid profile')
              expect(@analytics).to receive(:track_event).
                with('OpenID Connect: authorization request handoff',
                     success: true,
                     client_id: client_id,
                     user_sp_authorized: true,
                     code_digest: kind_of(String))
              expect(@analytics).to receive(:track_event).
                with(
                  'SP redirect initiated',
                  ial: 2,
                  billed_ial: 2,
                )

              IdentityLinker.new(user, service_provider).link_identity(ial: 2)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate verified_at],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              sp_return_log = SpReturnLog.find_by(issuer: client_id)
              expect(sp_return_log.ial).to eq(2)
            end
          end

          context 'account is not already verified' do
            it 'redirects to have the user verify their account' do
              action
              expect(controller).to redirect_to(idv_url)
            end

            context 'user has a pending profile' do
              context 'user has a gpo pending profile' do
                let(:user) { create(:profile, :verify_by_mail_pending).user }

                it 'redirects to gpo verify page' do
                  action
                  expect(controller).to redirect_to(idv_verify_by_mail_enter_code_url)
                end
              end

              context 'user has an in person pending profile' do
                let(:user) { create(:profile, :in_person_verification_pending).user }

                it 'redirects to in person ready to verify page' do
                  action
                  expect(controller).to redirect_to(idv_in_person_ready_to_verify_url)
                end
              end

              context 'user is under fraud review' do
                let(:user) { create(:profile, :fraud_review_pending).user }

                it 'redirects to fraud review page if fraud review is pending' do
                  action
                  expect(controller).to redirect_to(idv_please_call_url)
                end
              end

              context 'user is rejected due to fraud' do
                let(:user) { create(:profile, :fraud_rejection).user }

                it 'redirects to fraud rejection page if user is fraud rejected ' do
                  action
                  expect(controller).to redirect_to(idv_not_verified_url)
                end
              end

              context 'user has two pending reasons' do
                context 'user has gpo and fraud review pending' do
                  let(:user) do
                    create(
                      :profile,
                      :verify_by_mail_pending,
                      :fraud_review_pending,
                    ).user
                  end

                  it 'redirects to gpo verify page' do
                    action
                    expect(controller).to redirect_to(idv_verify_by_mail_enter_code_url)
                  end
                end

                context 'user has gpo and in person pending' do
                  let(:user) do
                    create(
                      :profile,
                      :verify_by_mail_pending,
                      :in_person_verification_pending,
                    ).user
                  end

                  it 'redirects to gpo verify page' do
                    action
                    expect(controller).to redirect_to(idv_verify_by_mail_enter_code_url)
                  end
                end
              end
            end
          end

          context 'profile is reset' do
            let(:user) { create(:profile, :verified, :password_reset).user }

            it 'redirects to have the user enter their personal key' do
              action
              expect(controller).to redirect_to(reactivate_account_url)
            end
          end
        end

        context 'with ialmax requested' do
          context 'provider is on the ialmax allow list' do
            before do
              params[:acr_values] = Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
              allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [client_id] }
            end

            context 'account is already verified' do
              let(:user) do
                create(
                  :profile, :active, :verified, proofing_components: { liveness_check: true }
                ).user
              end

              it 'redirects to the redirect_uri immediately when pii is unlocked if server-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('server_side')
                IdentityLinker.new(user, service_provider).link_identity(ial: 3)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
                action

                expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
              end

              it 'renders client-side redirect to the client app immediately if PII is unlocked and it is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side')

                IdentityLinker.new(user, service_provider).link_identity(ial: 3)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
                action

                expect(controller).to render_template('openid_connect/shared/redirect')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'renders JS client-side redirect to the client app immediately if PII is unlocked and it is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side_js')

                IdentityLinker.new(user, service_provider).link_identity(ial: 3)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
                action

                expect(controller).to render_template('openid_connect/shared/redirect_js')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'redirects to the password capture url when pii is locked' do
                IdentityLinker.new(user, service_provider).link_identity(ial: 3)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                allow(controller).to receive(:pii_requested_but_locked?).and_return(true)
                action

                expect(response).to redirect_to(capture_password_url)
              end

              it 'tracks IAL2 authentication event' do
                stub_analytics
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request',
                       success: true,
                       client_id: client_id,
                       prompt: 'select_account',
                       referer: nil,
                       allow_prompt_login: true,
                       errors: {},
                       unauthorized_scope: false,
                       user_fully_authenticated: true,
                       acr_values: 'http://idmanagement.gov/ns/assurance/ial/0',
                       code_challenge_present: false,
                       service_provider_pkce: nil,
                       scope: 'openid profile')
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request handoff',
                       success: true,
                       client_id: client_id,
                       user_sp_authorized: true,
                       code_digest: kind_of(String))
                expect(@analytics).to receive(:track_event).
                  with(
                    'SP redirect initiated',
                    ial: 0,
                    billed_ial: 2,
                  )

                IdentityLinker.new(user, service_provider).link_identity(ial: 2)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
                action

                sp_return_log = SpReturnLog.find_by(issuer: client_id)
                expect(sp_return_log.ial).to eq(2)
              end
            end

            context 'account is not already verified' do
              it 'redirects to the redirect_uri immediately without proofing if server-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('server_side')
                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action

                expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
              end

              it 'renders client-side redirect to the client app immediately if client-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side')

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action
                expect(controller).to render_template('openid_connect/shared/redirect')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'renders JS client-side redirect to the client app immediately if JS client-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side_js')

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action
                expect(controller).to render_template('openid_connect/shared/redirect_js')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'tracks IAL1 authentication event' do
                stub_analytics
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request',
                       success: true,
                       client_id: client_id,
                       prompt: 'select_account',
                       referer: nil,
                       allow_prompt_login: true,
                       errors: {},
                       unauthorized_scope: false,
                       user_fully_authenticated: true,
                       acr_values: 'http://idmanagement.gov/ns/assurance/ial/0',
                       code_challenge_present: false,
                       service_provider_pkce: nil,
                       scope: 'openid profile')
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request handoff',
                       success: true,
                       client_id: client_id,
                       user_sp_authorized: true,
                       code_digest: kind_of(String))
                expect(@analytics).to receive(:track_event).
                  with(
                    'SP redirect initiated',
                    ial: 0,
                    billed_ial: 1,
                  )

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                action

                sp_return_log = SpReturnLog.find_by(issuer: client_id)
                expect(sp_return_log.ial).to eq(1)
              end
            end

            context 'profile is reset' do
              let(:user) { create(:profile, :verified, :password_reset).user }

              it 'redirects to the redirect_uri immediately without proofing if server-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('server_side')

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action

                expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
              end

              it 'renders client-side redirect to the client app immediately if client-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side')

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action
                expect(controller).to render_template('openid_connect/shared/redirect')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'renders JS client-side redirect to the client app immediately if JS client-side redirect is enabled' do
                allow(IdentityConfig.store).to receive(:openid_connect_redirect).
                  and_return('client_side_js')

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )

                action
                expect(controller).to render_template('openid_connect/shared/redirect_js')
                expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
              end

              it 'tracks IAL1 authentication event' do
                stub_analytics
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request',
                       success: true,
                       client_id: client_id,
                       prompt: 'select_account',
                       referer: nil,
                       allow_prompt_login: true,
                       errors: {},
                       unauthorized_scope: false,
                       user_fully_authenticated: true,
                       acr_values: 'http://idmanagement.gov/ns/assurance/ial/0',
                       code_challenge_present: false,
                       service_provider_pkce: nil,
                       scope: 'openid profile')
                expect(@analytics).to receive(:track_event).
                  with('OpenID Connect: authorization request handoff',
                       success: true,
                       client_id: client_id,
                       user_sp_authorized: true,
                       code_digest: kind_of(String))
                expect(@analytics).to receive(:track_event).
                  with(
                    'SP redirect initiated',
                    ial: 0,
                    billed_ial: 1,
                  )

                IdentityLinker.new(user, service_provider).link_identity(ial: 1)
                user.identities.last.update!(
                  verified_attributes: %w[given_name family_name birthdate verified_at],
                )
                action

                sp_return_log = SpReturnLog.find_by(issuer: client_id)
                expect(sp_return_log.ial).to eq(1)
              end
            end
          end
        end

        context 'user has not approved this application' do
          it 'redirects verify shared attributes page' do
            action

            expect(response).to redirect_to(sign_up_completed_url)
          end

          it 'does not link identity to the user' do
            action
            expect(user.identities.count).to eq(0)
          end
        end

        context 'user has already approved this application' do
          before do
            IdentityLinker.new(user, service_provider).link_identity
            user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          end

          it 'redirects back to the client app with a code if client-side redirect is disabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('server_side')
            action

            expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

            redirect_params = UriService.params(response.location)

            expect(redirect_params[:code]).to be_present
            expect(redirect_params[:state]).to eq(params[:state])
          end

          it 'renders a client-side redirect back to the client app with a code if it is enabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side')

            action

            expect(controller).to render_template('openid_connect/shared/redirect')
            expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

            redirect_params = UriService.params(assigns(:oidc_redirect_uri))
            expect(redirect_params[:code]).to be_present
            expect(redirect_params[:state]).to eq(params[:state])
          end

          it 'renders a JS client-side redirect back to the client app with a code if it is enabled' do
            allow(IdentityConfig.store).to receive(:openid_connect_redirect).
              and_return('client_side_js')

            action

            expect(controller).to render_template('openid_connect/shared/redirect_js')
            expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

            redirect_params = UriService.params(assigns(:oidc_redirect_uri))
            expect(redirect_params[:code]).to be_present
            expect(redirect_params[:state]).to eq(params[:state])
          end
        end
      end

      context 'with invalid params that do not interfere with the redirect_uri' do
        before { params[:prompt] = '' }

        it 'redirects the user with an invalid request if client-side redirect is disabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = UriService.params(response.location)

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders client-side redirect with an invalid request if client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders JS client-side redirect with an invalid request if JS client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'redirects the user with an invalid request if UUID is in server-side redirect list' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
            and_return({ user.uuid => 'server_side' })
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = UriService.params(response.location)

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders client-side redirect with an invalid request if UUID is overriden for client-side redirect' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
            and_return({ user.uuid => 'client_side' })
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders JS client-side redirect with an invalid request if UUID is overriden for JS client-side redirect' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          allow(IdentityConfig.store).to receive(:openid_connect_redirect_uuid_override_map).
            and_return({ user.uuid => 'client_side_js' })
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'tracks the event with errors' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with('OpenID Connect: authorization request',
                 success: false,
                 client_id: client_id,
                 prompt: '',
                 referer: nil,
                 allow_prompt_login: true,
                 unauthorized_scope: true,
                 errors: hash_including(:prompt),
                 error_details: hash_including(:prompt),
                 user_fully_authenticated: true,
                 acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
                 code_challenge_present: false,
                 service_provider_pkce: nil,
                 scope: 'openid')
          expect(@analytics).to_not receive(:track_event).with('sp redirect initiated')

          action

          expect(SpReturnLog.count).to eq(0)
        end
      end

      context 'with invalid params that mean the redirect_uri is not trusted' do
        before { params.delete(:client_id) }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end

        it 'tracks the event with errors' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with('OpenID Connect: authorization request',
                 success: false,
                 client_id: nil,
                 prompt: 'select_account',
                 referer: nil,
                 allow_prompt_login: nil,
                 unauthorized_scope: true,
                 errors: hash_including(:client_id),
                 error_details: hash_including(:client_id),
                 user_fully_authenticated: true,
                 acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
                 code_challenge_present: false,
                 service_provider_pkce: nil,
                 scope: 'openid')
          expect(@analytics).to_not receive(:track_event).with('SP redirect initiated')

          action

          expect(SpReturnLog.count).to eq(0)
        end
      end
    end

    context 'user is not signed in' do
      context 'without valid acr_values' do
        before { params.delete(:acr_values) }

        it 'handles the error and does not blow up when server-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
        end

        it 'handles the error and does not blow up when client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
        end

        it 'handles the error and does not blow up when client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])
        end
      end

      context 'with a bad redirect_uri' do
        before { params[:redirect_uri] = '!!!' }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end
      end

      context 'ialmax requested when service provider is not in allowlist' do
        before do
          params[:acr_values] = Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
        end

        it 'redirects the user if server-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('server_side')
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = UriService.params(response.location)

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders a client-side redirect if client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side')
          action

          expect(controller).to render_template('openid_connect/shared/redirect')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'renders a JS client-side redirect if JS client-side redirect is enabled' do
          allow(IdentityConfig.store).to receive(:openid_connect_redirect).
            and_return('client_side_js')
          action

          expect(controller).to render_template('openid_connect/shared/redirect_js')
          expect(assigns(:oidc_redirect_uri)).to start_with(params[:redirect_uri])

          redirect_params = UriService.params(assigns(:oidc_redirect_uri))

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end
      end

      it 'redirects to SP landing page with the request_id in the params' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with('OpenID Connect: authorization request',
               success: true,
               client_id: client_id,
               prompt: 'select_account',
               referer: nil,
               allow_prompt_login: true,
               errors: {},
               unauthorized_scope: true,
               user_fully_authenticated: false,
               acr_values: 'http://idmanagement.gov/ns/assurance/ial/1',
               code_challenge_present: false,
               service_provider_pkce: nil,
               scope: 'openid')

        action
        sp_request_id = ServiceProviderRequestProxy.last.uuid

        expect(response).to redirect_to new_user_session_url
        expect(controller.session[:sp][:request_id]).to eq(sp_request_id)
      end

      it 'sets sp information in the session and does not transmit ial2 attrs for ial1' do
        action
        sp_request_id = ServiceProviderRequestProxy.last.uuid

        expect(session[:sp]).to eq(
          aal_level_requested: nil,
          piv_cac_requested: false,
          phishing_resistant_requested: false,
          ial: 1,
          ial2: false,
          ialmax: false,
          issuer: 'urn:gov:gsa:openidconnect:test',
          request_id: sp_request_id,
          request_url: request.original_url,
          requested_attributes: %w[],
          biometric_comparison_required: false,
        )
      end

      describe 'handling the :biometric_comparison_required parameter' do
        before do
          allow(Rails.env).to receive(:production?).and_return(production)
          if require_biometric_comparison
            params[:biometric_comparison_required] = 'true'
          else
            # Should be a no-op, but let's be paranoid.
            params.delete(:biometric_comparison_required)
          end

          action
        end

        context 'when the param value :biometric_comparison_required is "true"' do
          let(:require_biometric_comparison) { true }

          # Temporary barrier to public presentation. Update or remove
          # when we are ready to accept :biometric_comparison_required
          # in production. See LG-11962.
          context 'in production' do
            let(:production) { true }

            it 'does not set the :sp value' do
              expect(session).not_to include(:sp)
            end

            it 'redirects to /page_not_found' do
              expect(response).to redirect_to(page_not_found_path)
            end
          end

          context 'not in production' do
            let(:production) { false }

            it 'sets the session :biometric_comparison_required value to true' do
              expect(session[:sp][:biometric_comparison_required]).to eq(true)
            end
          end
        end

        context 'when the param value :biometric_comparison_required is not set' do
          let(:require_biometric_comparison) { false }

          context 'in production' do
            let(:production) { true }

            it 'sets the session :biometric_comparison_required value to false' do
              expect(session[:sp][:biometric_comparison_required]).to eq(false)
            end
          end

          context 'not in production' do
            let(:production) { false }

            it 'sets the session :biometric_comparison_required value to false' do
              expect(session[:sp][:biometric_comparison_required]).to eq(false)
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
