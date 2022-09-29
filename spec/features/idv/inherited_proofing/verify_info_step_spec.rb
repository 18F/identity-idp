require 'rails_helper'

feature 'inherited proofing verify info' do
  include IdvHelper
  include DocAuthHelper
  include_context 'va_user_context'

  before do
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing?).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing_auth_code).and_return auth_code
  end

  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  before do
    sign_in_and_2fa_user
    complete_inherited_proofing_steps_before_verify_step
  end

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
