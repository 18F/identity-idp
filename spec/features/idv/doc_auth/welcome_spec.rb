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

    it 'logs "intro_paragraph" learn more link click' do
      click_on t('doc_auth.info.getting_started_learn_more')

      expect(fake_analytics).to have_logged_event(
        'External Redirect',
        step: 'welcome',
        location: 'intro_paragraph',
        flow: 'idv',
        redirect_url: MarketingSite.help_center_article_url(
          category: 'verify-your-identity',
          article: 'overview',
        ),
      )
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
        expect(page).to have_content t('doc_auth.instructions.bullet1b')
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

      it 'displays only State ID instructions to the user' do
        expect(page).to have_content t('doc_auth.instructions.bullet1b')
      end
    end
  end
end
