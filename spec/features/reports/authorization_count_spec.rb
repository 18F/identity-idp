require 'rails_helper'

def visit_idp_from_ial1_saml_sp(issuer:)
  visit_saml_authn_request_url(
    overrides: {
      issuer: issuer,
      name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      authn_context: [
        Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}email,verified_at",
      ],
      security: {
        embed_sign: false,
      },
    },
  )
end

def visit_idp_from_ial2_saml_sp(issuer:)
  visit_saml_authn_request_url(
    overrides: {
      issuer: issuer,
      name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      authn_context: [
        Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
        "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
      ],
      security: {
        embed_sign: false,
      },
    },
  )
end

RSpec.describe 'authorization count' do
  include IdvFromSpHelper
  include OidcAuthHelper
  include DocAuthHelper

  let(:user) { nil }
  let(:today) { Time.zone.today }
  let(:client_id_1) { 'urn:gov:gsa:openidconnect:sp:server' }
  let(:client_id_2) { 'urn:gov:gsa:openidconnect:sp:server_two' }
  let(:issuer_1) { sp1_issuer }
  let(:issuer_2) { 'https://rp3.serviceprovider.com/auth/saml/metadata' }

  context 'an IAL1 user with an active session' do
    let(:user) { create(:user, :fully_registered) }

    before do
      reset_monthly_auth_count_and_login(user)
    end

    context 'using oidc' do
      it 'does not count second IAL1 auth at same sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial1_count_only(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_count_only(client_id_1)
      end

      it 'counts step up from IAL1 to IAL2 after proofing' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial1_count_only(client_id_1)

        create(:profile, :active, :verified, :with_pii, user: user)
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        fill_in t('account.index.password'), with: user.password
        click_submit_default
        click_agree_and_continue
        expect_ial1_and_ial2_count(client_id_1)
      end

      context 'the service provider is on the ialmax approved list' do
        before do
          allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [client_id_1] }
        end

        it 'counts IAL1 auth when ial max is requested' do
          visit_idp_from_ial_max_oidc_sp(client_id: client_id_1)
          click_agree_and_continue

          expect_ial1_count_only(client_id_1)
        end
      end

      context 'the service provider is not on the ialmax approved list' do
        it 'does not count the auth attempt' do
          visit_idp_from_ial_max_oidc_sp(client_id: client_id_1)

          expect(page).not_to have_content t('sign_up.agree_and_continue')
          expect_no_counts(issuer_1)
        end
      end
    end

    context 'using saml' do
      it 'does not count second IAL1 auth at same sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_continue
        expect_ial1_count_only(issuer_1)
      end

      it 'counts step up from IAL1 to IAL2 after proofing' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_count_only(issuer_1)

        create(:profile, :active, :verified, :with_pii, user: user)
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        fill_in t('account.index.password'), with: user.password
        click_submit_default_twice
        click_agree_and_continue
        click_submit_default
        expect_ial1_and_ial2_count(issuer_1)
      end

      # rubocop:disable Layout/LineLength
      context 'when ialmax is requested' do
        context 'provider is on the ialmax allow list' do
          before do
            allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [issuer_1] }
          end

          it 'counts IAL1 auth when ial max is requested' do
            visit_saml_authn_request_url(
              overrides: {
                issuer: issuer_1,
                name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                authn_context: [
                  Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
                security: {
                  embed_sign: false,
                },
              },
            )
            click_agree_and_continue
            click_submit_default

            expect_ial1_count_only(issuer_1)
          end
        end

        context 'provider is not on the ialmax allow list' do
          it 'does not count the auth attempt' do
            visit_saml_authn_request_url(
              overrides: {
                issuer: issuer_1,
                name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                authn_context: [
                  Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
                security: {
                  embed_sign: false,
                },
              },
            )

            expect(page).not_to have_content t('sign_up.agree_and_continue')
            expect_no_counts(issuer_1)
          end
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end

  context 'an IAL2 user with an active session' do
    let(:user) { create(:user, :proofed) }

    before do
      reset_monthly_auth_count_and_login(user)
    end

    context 'using oidc' do
      it 'counts IAL1 auth at same sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial1_and_ial2_count(client_id_1)
      end

      it 'does not count second IAL2 auth at same sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_continue
        expect_ial2_count_only(client_id_1)
      end

      it 'counts step up from IAL1 to IAL2 at another sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_count_only(client_id_2)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_and_ial2_count(client_id_2)
      end

      it 'counts IAL2 auth at another sp' do
        visit_idp_from_ial2_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial2_count_only(client_id_1)

        visit_idp_from_ial2_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial2_count_only(client_id_2)
      end

      it 'counts IAL1 auth at another sp' do
        visit_idp_from_ial1_oidc_sp(client_id: client_id_1)
        click_agree_and_continue
        expect_ial1_count_only(client_id_1)

        visit_idp_from_ial1_oidc_sp(client_id: client_id_2)
        click_agree_and_continue
        expect_ial1_count_only(client_id_2)
      end

      context 'ialmax is requested' do
        context 'provider is on the ialmax allowlist' do
          before do
            allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [client_id_1] }
          end

          it 'counts IAL2 auth when ial max is requested' do
            visit_idp_from_ial_max_oidc_sp(client_id: client_id_1)
            click_agree_and_continue

            expect_ial2_count_only(client_id_1)
          end
        end

        context 'provider is not on the ialmax allowlist' do
          it 'does not count the auth attempt' do
            visit_idp_from_ial_max_oidc_sp(client_id: client_id_1)

            expect(page).not_to have_content t('sign_up.agree_and_continue')
            expect_no_counts(client_id_1)
          end
        end
      end
    end

    context 'using saml' do
      it 'counts IAL1 auth at same sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_and_ial2_count(issuer_1)
      end

      it 'does not count second IAL2 auth at same sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_continue
        expect_ial2_count_only(issuer_1)
      end

      it 'counts step up from IAL1 to IAL2 at same sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_and_ial2_count(issuer_1)
      end

      it 'counts IAL1 auth at another sp' do
        visit_idp_from_ial1_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial1_count_only(issuer_1)

        visit_idp_from_ial1_saml_sp(issuer: issuer_2)
        click_agree_and_continue
        click_submit_default
        expect_ial1_count_only(issuer_2)
      end

      it 'counts IAL2 auth at another sp' do
        visit_idp_from_ial2_saml_sp(issuer: issuer_1)
        click_agree_and_continue
        click_submit_default
        expect_ial2_count_only(issuer_1)

        visit_idp_from_ial2_saml_sp(issuer: issuer_2)
        click_agree_and_continue
        click_submit_default
        expect_ial2_count_only(issuer_2)
      end

      # rubocop:disable Layout/LineLength
      context 'ialmax is requested' do
        context 'provider is on ialmax allow list' do
          before do
            allow(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [issuer_1] }
          end

          it 'counts IAL2 auth when ial max is requested' do
            visit_saml_authn_request_url(
              overrides: {
                issuer: issuer_1,
                name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                authn_context: [
                  Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
                security: {
                  embed_sign: false,
                },
              },
            )
            click_agree_and_continue
            click_submit_default
            expect_ial2_count_only(issuer_1)
          end
        end

        context 'provider is not on ialmax allow list' do
          it 'does not count the auth attempt' do
            visit_saml_authn_request_url(
              overrides: {
                issuer: issuer_1,
                name_identifier_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                authn_context: [
                  Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
                security: {
                  embed_sign: false,
                },
              },
            )

            expect(page).not_to have_content t('sign_up.agree_and_continue')
            expect_no_counts(issuer_1)
          end
        end
      end

      # rubocop:enable Layout/LineLength
    end
  end

  def expect_ial1_count_only(issuer)
    ial1_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 1)
    ial2_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 2)
    expect(ial1_return_logs.count).to eq(1)
    expect(ial2_return_logs.count).to eq(0)
  end

  def expect_ial2_count_only(issuer)
    ial1_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 1)
    ial2_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 2)
    expect(ial1_return_logs.count).to eq(0)
    expect(ial2_return_logs.count).to eq(1)
  end

  def expect_ial1_and_ial2_count(issuer)
    ial1_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 1)
    ial2_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 2)
    expect(ial1_return_logs.count).to eq(1)
    expect(ial2_return_logs.count).to eq(1)
  end

  def expect_no_counts(issuer)
    ial1_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 1)
    ial2_return_logs = SpReturnLog.where(issuer: issuer, billable: true, ial: 2)
    expect(ial1_return_logs.count).to eq(0)
    expect(ial2_return_logs.count).to eq(0)
  end

  def reset_monthly_auth_count_and_login(user)
    SpReturnLog.delete_all
    visit api_saml_logout_path(path_year: SamlAuthHelper::PATH_YEAR)
    sign_in_live_with_2fa(user)
  end
end
