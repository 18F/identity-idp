require 'rails_helper'

RSpec.feature 'the SSA forced upgrade to IAL2', allowed_extra_analytics: [:*] do
  include SamlAuthHelper
  include IdvHelper

  let(:authn_context) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }
  let(:issuer) { 'saml_sp_ial2' }
  let(:issuer_list) { [issuer] }
  before do
    allow(IdentityConfig.store).to receive(:allowed_ssa_force_ial2_providers)
      .and_return(issuer_list)

    visit_saml_authn_request_url(
      overrides: {
        issuer:,
        authn_context: [
          authn_context,
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}ssn",
        ],
      },
    )
  end

  context 'the user has not proofed' do
    it 'requires the user to complete proofing' do
      user = create(:user, :fully_registered)
      sign_in_live_with_2fa(user)
      click_submit_default

      expect(page).to have_current_path(idv_welcome_path, ignore_query: true)
    end

    context 'when auth-only is requested' do
      let(:authn_context) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

      it 'redirects to the SP without prompting the user to proof' do
        user = create(:user, :proofed)
        sign_in_live_with_2fa(user)
        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path, ignore_query: true)

        click_agree_and_continue

        click_submit_default

        expect(page).to have_current_path(
          api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
        )
      end
    end
  end

  context 'the user has proofed' do
    context 'with base idv' do
      it 'requires the user to complete proofing' do
        user = create(:user, :proofed)

        sign_in_live_with_2fa(user)

        click_submit_default

        expect(page).to have_current_path(idv_welcome_path, ignore_query: true)
      end

      context 'when the issuer is not on the allowed_ssa_force_ial2_providers allowlist' do
        let(:issuer_list) { [] }

        it 'redirects to the SP without prompting the user to proof' do
          user = create(
            :user,
            :proofed_with_selfie,
          )

          sign_in_live_with_2fa(user)
          click_submit_default

          expect(page).to have_current_path(sign_up_completed_path, ignore_query: true)

          click_agree_and_continue
          click_submit_default

          expect(page).to have_current_path(
            api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
          )
        end
      end
    end

    context 'with facial match' do
      it 'redirects to the SP without prompting the user to proof' do
        user = create(
          :user,
          :proofed_with_selfie,
        )

        sign_in_live_with_2fa(user)
        click_submit_default

        expect(page).to have_current_path(sign_up_completed_path, ignore_query: true)

        click_agree_and_continue
        click_submit_default

        expect(page).to have_current_path(
          api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
        )
      end
    end
  end
end
