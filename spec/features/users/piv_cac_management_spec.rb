require 'rails_helper'

feature 'PIV/CAC Management' do
  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end

  context 'with no piv/cac associated yet' do
    let(:uuid) { SecureRandom.uuid }
    let(:user) { create(:user, :signed_up, :with_phone, with: { phone: '+1 202-555-1212' }) }

    context 'with an account allowed to use piv/cac' do
      before(:each) do
        allow_any_instance_of(
          TwoFactorAuthentication::PivCacPolicy,
        ).to receive(:available?).and_return(true)
      end

      scenario 'allows association of a piv/cac with an account' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        expect(page).to have_link(t('forms.piv_cac_setup.submit'))

        nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_setup.submit')))

        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              uuid: uuid,
                              subject: 'SomeIgnoredSubject')

        expect(current_path).to eq account_path

        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to_not be_nil
        expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

        user.reload
        expect(user.x509_dn_uuid).to eq uuid
        expect(user.events.order(created_at: :desc).last.event_type).to eq('piv_cac_enabled')
      end

      scenario 'displays error for a bad piv/cac' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        expect(page).to have_link(t('forms.piv_cac_setup.submit'))

        nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_setup.submit')))
        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              error: 'certificate.bad')
        expect(current_path).to eq setup_piv_cac_path
        expect(page).to have_content(t('headings.piv_cac_setup.certificate.bad'))
      end

      scenario 'displays error for an expired piv/cac' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        click_link t('forms.buttons.enable'), href: setup_piv_cac_url

        expect(page).to have_link(t('forms.piv_cac_setup.submit'))

        nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_setup.submit')))
        visit_piv_cac_service(setup_piv_cac_url,
                              nonce: nonce,
                              error: 'certificate.expired')
        expect(current_path).to eq setup_piv_cac_path
        expect(page).to have_content(t('headings.piv_cac_setup.certificate.expired'))
      end

      scenario "doesn't allow unassociation of a piv/cac" do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to be_nil
      end

      context 'when the user does not have a 2nd mfa yet' do
        it 'does prompt to set one up after configuring PIV/CAC' do
          stub_piv_cac_service

          user.update(otp_secret_key: 'secret')
          MfaContext.new(user).phone_configurations.clear
          sign_in_and_2fa_user(user)
          visit account_path
          click_link t('forms.buttons.enable'), href: setup_piv_cac_url

          expect(page).to have_current_path(setup_piv_cac_path)

          nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_setup.submit')))
          visit_piv_cac_service(setup_piv_cac_url,
                                nonce: nonce,
                                uuid: SecureRandom.uuid,
                                subject: 'SomeIgnoredSubject')

          expect(page).to have_current_path account_path
        end
      end
    end

    context 'with an account not allowed to use piv/cac' do
      before(:each) do
        allow_any_instance_of(
          TwoFactorAuthentication::PivCacPolicy,
        ).to receive(:available?).and_return(false)
      end

      scenario "doesn't advertise association of a piv/cac with an account" do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)
      end

      scenario "doesn't allow unassociation of a piv/cac" do
        stub_piv_cac_service

        user = create(:user, :signed_up, :with_phone, with: { phone: '+1 202-555-1212' })
        sign_in_and_2fa_user(user)
        visit account_path
        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to be_nil
      end
    end
  end

  context 'with a piv/cac associated' do
    let(:user) do
      create(:user, :signed_up, :with_piv_or_cac, :with_phone, with: { phone: '+1 202-555-1212' })
    end

    scenario "doesn't allow association of another piv/cac with the account" do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_path
      expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)
    end

    scenario 'allows disassociation of the piv/cac' do
      stub_piv_cac_service

      sign_in_and_2fa_user(user)
      visit account_path

      form = find_form(page, action: disable_piv_cac_url)
      expect(form).to_not be_nil

      form.click_button(t('forms.buttons.disable'))

      expect(current_path).to eq account_path

      form = find_form(page, action: disable_piv_cac_url)
      expect(form).to be_nil
      expect(page).to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

      user.reload
      expect(user.x509_dn_uuid).to be_nil
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
      expect(user.x509_dn_uuid).to_not be_nil
    end
  end
end
