require 'rails_helper'

feature 'PIV/CAC Management' do

  def find_form(page, attributes)
    page.all('form').detect do |form|
      attributes.all? { |key, value| form[key] == value }
    end
  end

  before(:each) do
    allow(Figaro.env).to receive(:piv_cac_enabled).and_return('true')
  end

  context 'with no piv/cac associated yet' do
    let(:uuid) { SecureRandom.uuid }
    let(:user) { create(:user, :signed_up, phone: '+1 202-555-1212') }

    context 'with a service provider allowed to use piv/cac' do
      let(:identity_with_sp) do
        Identity.create(
          user_id: user.id,
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.now,
        )
      end

      before(:each) do
        user.identities << [identity_with_sp]
        allow(Figaro.env).to receive(:piv_cac_agencies).and_return(
          ['Test Government Agency'].to_json
        )
        PivCacService.send(:reset_piv_cac_avaialable_agencies)
      end

      scenario 'allows association of a piv/cac with an account' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        expect(page).to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

        visit setup_piv_cac_url
        expect(page).to have_link(t('forms.piv_cac_setup.submit'))
        nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_setup.submit')))

        visit_piv_cac_service(setup_piv_cac_url, {
          nonce: nonce,
          uuid: uuid,
          subject: 'SomeIgnoredSubject'
        })

        expect(current_path).to eq account_path

        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to_not be_nil
        expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

        user.reload
        expect(user.x509_dn_uuid).to eq uuid
      end

      scenario "doesn't allow unassociation of a piv/cac" do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to be_nil
      end
    end

    context 'with a service provider not allowed to use piv/cac' do
      let(:identity_with_sp) do
        Identity.create(
          user_id: user.id,
          service_provider: 'http://localhost:3000',
          last_authenticated_at: Time.now,
        )
      end

      before(:each) do
        user.identities << [identity_with_sp]
        allow(Figaro.env).to receive(:piv_cac_agencies).and_return('[]')
        PivCacService.send(:reset_piv_cac_avaialable_agencies)
      end

      scenario 'does not allow association of a piv/cac with an account' do
        stub_piv_cac_service

        sign_in_and_2fa_user(user)
        visit account_path
        expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)
      end

      scenario "doesn't allow unassociation of a piv/cac" do
        stub_piv_cac_service

        user = create(:user, :signed_up, phone: '+1 202-555-1212')
        sign_in_and_2fa_user(user)
        visit account_path
        form = find_form(page, action: disable_piv_cac_url)
        expect(form).to be_nil
      end
    end
  end

  context 'with a piv/cac associated and no identities allowing piv/cac' do
    let(:user) do
      create(:user, :signed_up, :with_piv_or_cac, phone: '+1 202-555-1212')
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
      expect(page).not_to have_link(t('forms.buttons.enable'), href: setup_piv_cac_url)

      user.reload
      expect(user.x509_dn_uuid).to be_nil
    end
  end
end
