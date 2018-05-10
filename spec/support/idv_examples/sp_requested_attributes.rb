shared_examples 'sp requesting attributes' do |sp|
  include SamlAuthHelper
  include IdvHelper

  before do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  end

  let(:user) { user_with_2fa }

  context 'visiting an SP for the first time' do
    it 'requires the user to verify the attributes submitted to the SP' do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default

      expect(current_path).to eq verify_path

      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key

      expect(current_path).to eq(sign_up_completed_path)

      within('.requested-attributes') do
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to_not have_content t('help_text.requested_attributes.address')
        expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
        expect(page).to have_content t('help_text.requested_attributes.full_name')
        expect(page).to have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
      end
    end
  end

  context 'visiting an SP the user has already signed into' do
    before do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default
      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key
      click_on I18n.t('forms.buttons.continue')
      visit account_path
      first(:link, t('links.sign_out')).click
      click_submit_default if sp == :saml # SAML SLO request
    end

    it 'does not require the user to verify attributes' do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default

      if sp == :oidc
        expect(current_url).to include('http://localhost:7654/auth/result')
      elsif sp == :saml
        expect(current_url).to include(api_saml_auth_url)
      end
    end
  end
end
