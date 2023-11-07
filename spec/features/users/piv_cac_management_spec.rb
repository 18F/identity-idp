require 'rails_helper'

RSpec.feature 'PIV/CAC Management' do
  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end

  context 'with no piv/cac associated yet' do
    let(:uuid) { SecureRandom.uuid }
    let(:user) { create(:user, :fully_registered, :with_phone, with: { phone: '+1 202-555-1212' }) }

    scenario 'allows association of a piv/cac with an account' do
      allow(Identity::Hostdata).to receive(:env).and_return('test')
      allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      expect(page.response_headers['Content-Security-Policy']).
        to(include("form-action https://*.pivcac.test.example.com 'self';"))

      nonce = piv_cac_nonce_from_form_action

      visit_piv_cac_service(
        setup_piv_cac_url,
        nonce:,
        uuid:,
        subject: 'SomeIgnoredSubject',
      )

      expect(current_path).to eq account_path
      visit account_two_factor_authentication_path
      expect(page.find('.remove-piv')).to_not be_nil

      user.reload
      expect(user.piv_cac_configurations.first.x509_dn_uuid).to eq uuid
      expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_enabled')
    end

    scenario 'disallows add if 2 piv cacs' do
      stub_piv_cac_service
      user_id = user.id
      ::PivCacConfiguration.create!(user_id:, x509_dn_uuid: 'foo', name: 'key1')

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path

      expect(page).to have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)
      visit account_two_factor_authentication_path

      ::PivCacConfiguration.create!(user_id:, x509_dn_uuid: 'bar', name: 'key2')
      visit account_two_factor_authentication_path
      expect(page).to_not have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)

      visit setup_piv_cac_path
      expect(current_path).to eq account_two_factor_authentication_path
    end

    scenario 'disallows association of a piv/cac with the same name' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      nonce = piv_cac_nonce_from_form_action

      visit_piv_cac_service(
        setup_piv_cac_url,
        nonce:,
        uuid:,
        subject: 'SomeIgnoredSubject',
      )

      expect(current_path).to eq account_path

      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url
      user.reload
      fill_in 'name', with: user.piv_cac_configurations.first.name
      click_button t('forms.piv_cac_setup.submit')

      expect(page).to have_content(I18n.t('errors.piv_cac_setup.unique_name'))
    end

    scenario 'displays error for piv/cac with no certificate and accepts more error info' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      nonce = piv_cac_nonce_from_form_action
      visit_piv_cac_service(
        setup_piv_cac_url,
        nonce:,
        error: 'certificate.none',
        key_id: 'AB:CD:EF',
      )
      expect(current_path).to eq setup_piv_cac_error_path
      expect(page).to have_link(t('instructions.mfa.piv_cac.try_again'), href: setup_piv_cac_url)
      expect(page).to have_content(
        t(
          'instructions.mfa.piv_cac.no_certificate_html',
          try_again_html: t('instructions.mfa.piv_cac.try_again'),
        ),
      )
    end

    scenario 'displays error for expires certificate piv/cac and accepts more error info' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_two_factor_authentication_path
      click_link t('account.index.piv_cac_add'), href: setup_piv_cac_url

      nonce = piv_cac_nonce_from_form_action
      visit_piv_cac_service(
        setup_piv_cac_url,
        nonce:,
        error: 'certificate.expired',
        key_id: 'AB:CD:EF',
      )
      expect(current_path).to eq setup_piv_cac_error_path
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

    scenario "doesn't allow unassociation of a piv/cac" do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_path
      form = find_form(page, action: disable_piv_cac_url)
      expect(form).to be_nil
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

      expect(page.find('.remove-piv')).to_not be_nil
      page.find('.remove-piv').click

      expect(current_path).to eq piv_cac_delete_path
      click_on t('account.index.piv_cac_confirm_delete')

      expect(current_path).to eq account_two_factor_authentication_path

      expect(page).to have_link(t('account.index.piv_cac_add'), href: setup_piv_cac_url)

      user.reload
      expect(user.piv_cac_configurations.first&.x509_dn_uuid).to be_nil
      expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_disabled')
    end
  end

  context 'with PIV/CAC as the only MFA method' do
    let(:user) { create(:user, :with_piv_or_cac) }

    scenario 'disallows disassociation PIV/CAC' do
      sign_in_and_2fa_user(user)
      visit account_path

      form = find_form(page, action: disable_piv_cac_url)
      expect(form).to be_nil

      user.reload
      expect(user.piv_cac_configurations.first.x509_dn_uuid).to_not be_nil
    end
  end
end
