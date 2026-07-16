require 'rails_helper'

RSpec.feature 'welcome step' do
  include IdvHelper
  include DocAuthHelper
  include AbTestsHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(sp_name)
  end

  context 'happy path' do
    before do
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_welcome_step
    end

    it 'renders the redesigned welcome content' do
      expect(page).to have_content(
        t('headings.identity_verification_intro.title', sp: sp_name),
      )
      expect(page).to have_content(
        t('headings.identity_verification_intro.what_youll_need'),
      )
      expect(page).to have_button(t('doc_auth.buttons.continue'))
      expect(page).to have_link(t('idv.buttons.phone.no_us_phone_number'))
    end
  end

  context 'sp reproof banner' do
    before do
      allow(IdentityConfig.store).to receive(:feature_show_sp_reproof_banner_enabled)
        .and_return(true)
    end

    context 'when user has proofed before' do
      let(:user) { create(:user, :fully_registered) }

      before do
        create(:profile, :deactivated, :with_pii, user: user)

        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_live_with_2fa(user)
        complete_doc_auth_steps_before_welcome_step
      end

      it 'displays the reproof banner with correct messaging' do
        expect(page).to have_content(
          t('doc_auth.info.welcome_sp_reproof_alert', sp_name: sp_name),
        )

        expect(page).to have_content(
          t('doc_auth.headings.welcome_sp_reproof', sp_name: sp_name),
        )

        expect(page).to have_content(
          t('headings.identity_verification_intro.intro', sp: sp_name),
        )
      end
    end

    context 'when feature flag is disabled' do
      let(:user) { create(:user, :fully_registered) }

      before do
        create(:profile, :deactivated, :with_pii, user: user)

        allow(IdentityConfig.store).to receive(:feature_show_sp_reproof_banner_enabled)
          .and_return(false)
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_live_with_2fa(user)
        complete_doc_auth_steps_before_welcome_step
      end

      it 'does not display the reproof banner' do
        expect(page).not_to have_content(
          t('doc_auth.info.welcome_sp_reproof_alert', sp_name: sp_name),
        )
      end
    end
  end

  context 'passport flow' do
    context 'when passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
          .and_return(true)
        allow(IdentityConfig.store).to receive(:doc_auth_passports_percent)
          .and_return(100)
        reload_ab_tests
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_and_2fa_user
        complete_doc_auth_steps_before_welcome_step
      end

      it 'displays passport and state ID instructions to the user' do
        expect(page).to have_content(
          t('headings.identity_verification_intro.requirement_id_title'),
        )
      end
    end

    context 'when passports are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
          .and_return(false)
        reload_ab_tests
        visit_idp_from_sp_with_ial2(:oidc)
        sign_in_and_2fa_user
        complete_doc_auth_steps_before_welcome_step
      end

      it 'displays ID instructions to the user' do
        expect(page).to have_content(
          t('headings.identity_verification_intro.requirement_id_title'),
        )
      end
    end
  end
end
