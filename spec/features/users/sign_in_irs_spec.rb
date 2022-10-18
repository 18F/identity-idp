require 'rails_helper'

feature 'Sign in to the IRS' do
  before(:all) do
    @original_capyabara_wait = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 5
  end

  after(:all) do
    Capybara.default_max_wait_time = @original_capyabara_wait
  end

  include IdvHelper

  let(:irs) { create(:service_provider, :irs) }
  let(:other_irs) { create(:service_provider, :irs) }
  let(:not_irs) { create(:service_provider, active: true, ial: 2) }

  let(:initiating_service_provider_issuer) { irs.issuer }

  let(:user) do
    create(
      :profile, :active, :verified,
      pii: { first_name: 'John', ssn: '111223333' },
      initiating_service_provider_issuer: initiating_service_provider_issuer
    ).user
  end

  context 'user verified with IRS returns to IRS' do
    context 'user visits the same IRS SP they verified with' do
      it "accepts the user's identity as verified" do
        visit_idp_from_oidc_sp_with_ial2(client_id: irs.issuer)
        fill_in_credentials_and_submit(user.email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_agree_and_continue

        expect(current_url).to start_with('http://localhost:7654/auth/result')
      end
    end

    context 'user visits different IRS SP than the one they verified with' do
      it "accepts the user's identity as verified" do
        visit_idp_from_oidc_sp_with_ial2(client_id: other_irs.issuer)
        fill_in_credentials_and_submit(user.email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_agree_and_continue

        expect(current_url).to start_with('http://localhost:7654/auth/result')
      end
    end
  end

  context 'user verified with other agency signs in to IRS' do
    let(:initiating_service_provider_issuer) { not_irs.issuer }

    it 'forces the user to re-verify their identity' do
      visit_idp_from_oidc_sp_with_ial2(client_id: irs.issuer)
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
    end
  end
end
