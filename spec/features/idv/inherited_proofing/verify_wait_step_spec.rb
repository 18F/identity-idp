require 'rails_helper'

feature 'inherited proofing verify wait', :js do
  include InheritedProofingWithServiceProviderHelper

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return(true)
    send_user_from_service_provider_to_login_gov_openid_connect(user, inherited_proofing_auth)
  end

  let!(:user) { user_with_2fa }
  let(:inherited_proofing_auth) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }
  let(:fake_analytics) { FakeAnalytics.new }

  context 'when on the "How verifying your identify works" page, ' \
    'and the user clicks the "Continue" button' do
    before do
      complete_steps_up_to_inherited_proofing_we_are_retrieving_step user
    end

    context 'when there are no service-related errors' do
      it 'displays the "Verify your information" page' do
        expect(page).to have_current_path(
          idv_inherited_proofing_step_path(step: :verify_info),
        )
      end
    end

    context 'when there are service-related errors on the first attempt' do
      let(:inherited_proofing_auth) { 'invalid-auth-code' }

      it 'displays the warning page and allows retries' do
        expect(page).to have_current_path(
          idv_inherited_proofing_errors_no_information_path(flow: :inherited_proofing),
        )
        expect(page).to have_selector(:link_or_button, t('inherited_proofing.buttons.try_again'))
      end
    end

    context 'when there are service-related errors on the second attempt' do
      let(:inherited_proofing_auth) { 'invalid-auth-code' }

      it 'redirects to the error page, prohibits retries and logs the event' do
        click_button t('inherited_proofing.buttons.try_again')
        expect(page).to have_current_path(
          idv_inherited_proofing_errors_failure_url(flow: :inherited_proofing),
        )
        expect(fake_analytics).to have_logged_event(
          'Throttler Rate Limit Triggered',
          throttle_type: :inherited_proofing,
          step_name: Idv::Actions::InheritedProofing::RedoRetrieveUserInfoAction.name,
        )
      end
    end
  end

  context 'when the async state is missing during polling' do
    before do
      allow_any_instance_of(ProofingSessionAsyncResult).to receive(:missing?).and_return(true)
      complete_steps_up_to_inherited_proofing_we_are_retrieving_step user
    end

    it 'redirects back to the agreement step and logs the event' do
      expect(page).to have_current_path(
        idv_inherited_proofing_step_path(step: :agreement),
      )
      expect(fake_analytics).to have_logged_event(
        'Proofing Resolution Result Missing',
      )
    end
  end
end
