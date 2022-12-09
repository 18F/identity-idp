require 'rails_helper'

feature 'inherited proofing verify info' do
  include InheritedProofingHelper
  include_context 'va_user_context'

  before do
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing?).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing_auth_code).and_return auth_code
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(@decorated_session).to receive(:sp_logo_url).and_return('')
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:decorated_session).and_return(@decorated_session)
    sign_in_and_2fa_user
    complete_inherited_proofing_steps_before_verify_step
  end

  let(:sp_name) { 'VA.gov' }
  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  describe 'page content' do
    it 'renders the Continue button' do
      expect(page).to have_button(t('inherited_proofing.buttons.continue'))
    end

    it 'renders content' do
      expect(page).to have_content(t('titles.idv.verify_info'))
      expect(page).to have_link(
        t(
          'inherited_proofing.troubleshooting.options.get_help',
          sp_name: sp_name,
        ),
      )
    end
  end

  describe 'user info' do
    it "displays the user's personal information" do
      expect(page).to have_text user_attributes[:first_name]
      expect(page).to have_text user_attributes[:last_name]
      expect(page).to have_text user_attributes[:birth_date]
    end

    it "displays the user's address" do
      expect(page).to have_text user_attributes[:address][:street]
      expect(page).to have_text user_attributes[:address][:city]
      expect(page).to have_text user_attributes[:address][:state]
      expect(page).to have_text user_attributes[:address][:zip]
    end

    it "obfuscates the user's ssn" do
      expect(page).to have_text '1**-**-***9'
    end

    it "can display the user's ssn when selected" do
      check 'Show Social Security number'
      expect(page).to have_text '123-45-6789'
    end
  end
end
