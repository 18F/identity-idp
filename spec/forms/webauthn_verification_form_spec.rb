require 'rails_helper'

RSpec.describe WebauthnVerificationForm do
  include Rails.application.routes.url_helpers
  include WebAuthnHelper

  let(:user) { create(:user) }
  let(:challenge) { webauthn_challenge }
  let(:webauthn_error) { nil }
  let(:screen_lock_error) { nil }
  let(:platform_authenticator) { false }
  let(:client_data_json) { verification_client_data_json }
  let(:webauthn_aaguid) { nil }
  let!(:webauthn_configuration) do
    return if !user
    create(
      :webauthn_configuration,
      user: user,
      credential_id: credential_id,
      credential_public_key: credential_public_key,
      platform_authenticator: platform_authenticator,
      aaguid: webauthn_aaguid,
    )
  end

  subject(:form) do
    WebauthnVerificationForm.new(
      user: user,
      platform_authenticator:,
      url_options: {},
      challenge: challenge,
      protocol: protocol,
      authenticator_data: authenticator_data,
      client_data_json: client_data_json,
      signature: signature,
      credential_id: credential_id,
      webauthn_error: webauthn_error,
      screen_lock_error:,
    )
  end

  describe '#submit' do
    before do
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
    end

    subject(:result) { form.submit }

    context 'when the input is valid' do
      context 'security key' do
        it 'returns successful result' do
          expect(result.to_h).to eq(
            success: true,
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'for platform authenticator' do
        let(:platform_authenticator) { true }
        let(:webauthn_aaguid) { aaguid }

        it 'returns successful result' do
          expect(result.to_h).to eq(
            success: true,
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: aaguid,
          )
        end
      end

      context 'with client-side webauthn error as blank string' do
        let(:webauthn_error) { '' }

        it 'returns successful result excluding frontend_error' do
          expect(result.to_h).to eq(
            success: true,
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end
    end

    context 'when the input is invalid' do
      context 'when challenge is missing' do
        let(:challenge) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              challenge: { blank: true },
              authenticator_data: { invalid_authenticator_data: true },
            },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when authenticator data is missing' do
        let(:authenticator_data) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              authenticator_data: { blank: true, invalid_authenticator_data: true },
            },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when client_data_json is missing' do
        let(:client_data_json) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              client_data_json: { blank: true },
              authenticator_data: { invalid_authenticator_data: true },
            },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when signature is missing' do
        let(:signature) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: {
              signature: { blank: true },
              authenticator_data: { invalid_authenticator_data: true },
            },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when user has no configured webauthn' do
        let(:webauthn_configuration) { nil }

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { webauthn_configuration: { blank: true } },
            webauthn_configuration_id: nil,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when a client-side webauthn error is present' do
        let(:webauthn_error) { 'NotAllowedError' }

        it 'returns unsuccessful result including client-side webauthn error text' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { webauthn_error: { present: true } },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: webauthn_error,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when a screen lock error is present' do
        let(:screen_lock_error) { 'true' }

        context 'user does not have another authentication method available' do
          it 'returns unsuccessful result' do
            expect(result.to_h).to eq(
              success: false,
              error_details: {
                screen_lock_error: { present: true },
              },
              webauthn_configuration_id: webauthn_configuration.id,
              frontend_error: nil,
              webauthn_aaguid: nil,
            )
          end

          it 'provides error message not suggesting other method' do
            expect(result.first_error_message).to eq t(
              'two_factor_authentication.webauthn_error.screen_lock_no_other_mfa',
              link_html: link_to(
                t('two_factor_authentication.webauthn_error.use_a_different_method'),
                login_two_factor_options_path,
              ),
            )
          end
        end

        context 'user has another WebAuthn method available' do
          context 'the other MFA method is WebAuthn of the same attachment' do
            let(:platform_authenticator) { false }
            let(:user) { create(:user, :with_webauthn) }

            it 'returns unsuccessful result' do
              expect(result.to_h).to eq(
                success: false,
                error_details: {
                  screen_lock_error: { present: true },
                },
                webauthn_configuration_id: webauthn_configuration.id,
                frontend_error: nil,
                webauthn_aaguid: nil,
              )
            end

            it 'provides error message not suggesting other method' do
              expect(result.first_error_message).to eq t(
                'two_factor_authentication.webauthn_error.screen_lock_no_other_mfa',
                link_html: link_to(
                  t('two_factor_authentication.webauthn_error.use_a_different_method'),
                  login_two_factor_options_path,
                ),
              )
            end
          end

          context 'the other MFA method is WebAuthn of a different attachment' do
            let(:platform_authenticator) { false }
            let(:user) { create(:user, :with_webauthn_platform) }

            it 'returns unsuccessful result' do
              expect(result.to_h).to eq(
                success: false,
                error_details: {
                  screen_lock_error: { present: true },
                },
                webauthn_configuration_id: webauthn_configuration.id,
                frontend_error: nil,
                webauthn_aaguid: nil,
              )
            end

            it 'provides error message suggesting other method' do
              expect(result.first_error_message).to eq t(
                'two_factor_authentication.webauthn_error.screen_lock_other_mfa_html',
                link_html: link_to(
                  t('two_factor_authentication.webauthn_error.use_a_different_method'),
                  login_two_factor_options_path,
                ),
              )
            end
          end

          context 'the other MFA method is not a WebAuthn method' do
            let(:user) { create(:user, :with_phone) }

            it 'returns unsuccessful result' do
              expect(result.to_h).to eq(
                success: false,
                error_details: {
                  screen_lock_error: { present: true },
                },
                webauthn_configuration_id: webauthn_configuration.id,
                frontend_error: nil,
                webauthn_aaguid: nil,
              )
            end

            it 'provides error message suggesting other method' do
              expect(result.first_error_message).to eq t(
                'two_factor_authentication.webauthn_error.screen_lock_other_mfa_html',
                link_html: link_to(
                  t('two_factor_authentication.webauthn_error.use_a_different_method'),
                  login_two_factor_options_path,
                ),
              )
            end
          end
        end
      end

      context 'when origin is invalid' do
        before do
          allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:6666')
        end

        it 'returns unsuccessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { authenticator_data: { invalid_authenticator_data: true } },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end

      context 'when verification raises OpenSSL exception' do
        before do
          allow_any_instance_of(WebAuthn::AuthenticatorAssertionResponse).to receive(:verify).
            and_raise(OpenSSL::PKey::PKeyError)
        end

        it 'returns unsucessful result' do
          expect(result.to_h).to eq(
            success: false,
            error_details: { authenticator_data: { invalid_authenticator_data: true } },
            webauthn_configuration_id: webauthn_configuration.id,
            frontend_error: nil,
            webauthn_aaguid: nil,
          )
        end
      end
    end
  end
end
