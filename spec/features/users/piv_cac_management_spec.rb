require 'rails_helper'

RSpec.feature 'PIV/CAC Management' do
  context 'with no piv/cac associated yet' do
    let(:uuid) { SecureRandom.uuid }
    let(:user) { create(:user, :fully_registered, :with_phone, with: { phone: '+1 202-555-1212' }) }

    scenario 'allows association of a piv/cac with an account' do
      allow(Identity::Hostdata).to receive(:env).and_return('test')
      allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

      stub_piv_cac_service(uuid:)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      expect(page.response_headers['Content-Security-Policy'].split(';').map(&:strip))
        .to(include("form-action https://*.pivcac.test.example.com 'self'"))

      fill_in t('instructions.mfa.piv_cac.step_1'), with: 'Card'
      click_on t('forms.piv_cac_setup.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path account_path
      visit account_two_factor_authentication_path
      user.reload
      expect(page).to have_link(href: edit_piv_cac_path(id: user.piv_cac_configurations.first.id))

      expect(user.piv_cac_configurations.first.x509_dn_uuid).to eq uuid
      expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_enabled')
    end

    scenario 'disallows add if 2 piv cacs' do
      stub_piv_cac_service
      user_id = user.id
      ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'foo', name: 'key1')

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)
      visit account_two_factor_authentication_path

      ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: 'bar', name: 'key2')
      visit account_two_factor_authentication_path
      expect(page).to_not have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)

      visit setup_piv_cac_path
      expect(page).to have_current_path account_two_factor_authentication_path
    end

    scenario 'disallows association of a piv/cac with the same name' do
      stub_piv_cac_service(uuid:)

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      fill_in t('instructions.mfa.piv_cac.step_1'), with: 'Card'
      click_on t('forms.piv_cac_setup.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path account_path

      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url
      user.reload
      fill_in 'name', with: user.piv_cac_configurations.first.name
      click_button t('forms.piv_cac_setup.submit')

      expect(page).to have_content(I18n.t('errors.piv_cac_setup.unique_name'))
    end

    scenario 'displays error for piv/cac with no certificate and accepts more error info' do
      stub_piv_cac_service(error: 'certificate.none')

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      fill_in t('instructions.mfa.piv_cac.step_1'), with: 'Card'
      click_on t('forms.piv_cac_setup.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path(setup_piv_cac_error_path, ignore_query: true)
      expect(page).to have_link(t('instructions.mfa.piv_cac.try_again'), href: setup_piv_cac_url)
      expect(page).to have_content(
        t(
          'instructions.mfa.piv_cac.no_certificate_html',
          try_again_html: t('instructions.mfa.piv_cac.try_again'),
        ),
      )
    end

    scenario 'displays error for expires certificate piv/cac and accepts more error info' do
      stub_piv_cac_service(error: 'certificate.expired')

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      fill_in t('instructions.mfa.piv_cac.step_1'), with: 'Card'
      click_on t('forms.piv_cac_setup.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path(setup_piv_cac_error_path, ignore_query: true)
      expect(page).to have_link(
        t('instructions.mfa.piv_cac.please_try_again'),
        href: setup_piv_cac_url,
      )

      expect(page).to have_content(
        t(
          'instructions.mfa.piv_cac.did_not_work_html',
          please_try_again_html: t('instructions.mfa.piv_cac.please_try_again'),
        ),
      )
    end
  end

  context 'with a piv/cac associated' do
    let(:user) do
      create(
        :user,
        :fully_registered,
        :with_piv_or_cac,
        :with_phone,
        with: { phone: '+1 202-555-1212' },
      )
    end
    let(:piv_name) { 'My PIV Card' }

    scenario 'does allow association of another piv/cac with the account' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      expect(page).to have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)
    end

    scenario 'allows disassociation of the piv/cac' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_content(piv_name)

      click_link(
        format(
          '%s: %s',
          t('two_factor_authentication.piv_cac.manage_accessible_label'),
          piv_name,
        ),
      )

      expect(page).to have_current_path(
        edit_piv_cac_path(id: user.piv_cac_configurations.first.id),
      )
      click_button t('two_factor_authentication.piv_cac.delete')

      expect(page).to have_content(t('two_factor_authentication.piv_cac.deleted'))

      user.reload
      expect(user.piv_cac_configurations.first&.x509_dn_uuid).to be_nil
      expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_disabled')
    end
  end

  context 'with PIV/CAC as the only MFA method' do
    let(:user) { create(:user, :with_piv_or_cac) }

    scenario 'disallows disassociation PIV/CAC', :js, allow_browser_log: true do
      sign_in_and_2fa_user(user)
      visit account_path

      click_button(
        format(
          '%s: %s',
          t('two_factor_authentication.piv_cac.manage_accessible_label'),
          user.piv_cac_configurations.first.name,
        ),
      )
      accept_confirm(wait: 5) { click_button t('components.manageable_authenticator.delete') }
      expect(page).to have_content(
        t('errors.manage_authenticator.remove_only_method_error'),
        wait: 5,
      )

      user.reload
      expect(user.piv_cac_configurations.first.x509_dn_uuid).to_not be_nil
    end
  end
end
