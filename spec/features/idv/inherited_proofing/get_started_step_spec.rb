require 'rails_helper'

feature 'inherited proofing get started' do
  include InheritedProofingHelper

  before do
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing?).and_return true
    allow_any_instance_of(Idv::InheritedProofingController).to \
      receive(:va_inherited_proofing_auth_code).and_return auth_code
  end

  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  def expect_ip_get_started_step
    expect(page).to have_current_path(idv_ip_get_started_step)
  end

  def expect_inherited_proofing_get_started_step
    expect(page).to have_current_path(idv_ip_get_started_step)
  end

  context 'when JS is enabled', :js do
    before do
      sign_in_and_2fa_user
      complete_inherited_proofing_steps_before_get_started_step
    end

    context 'when clicking on the Cancel link' do
      it 'redirects to the Cancellation UI' do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :get_started))
      end
    end
  end

  context 'when JS is disabled' do
    before do
      sign_in_and_2fa_user
      complete_inherited_proofing_steps_before_get_started_step
    end

    context 'when clicking on the Cancel link' do
      it 'redirects to the Cancellation UI' do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :get_started))
      end
    end
  end
end
