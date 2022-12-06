require 'rails_helper'

feature 'inherited proofing cancel process', :js do
  include InheritedProofingWithServiceProviderHelper

  before do
    allow(IdentityConfig.store).to receive(:va_inherited_proofing_mock_enabled).and_return true
    send_user_from_service_provider_to_login_gov_openid_connect user, inherited_proofing_auth
  end

  let!(:user) { user_with_2fa }
  let(:inherited_proofing_auth) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  context 'from the "Get started verifying your identity" view, and clicking the "Cancel" link' do
    before do
      complete_steps_up_to_inherited_proofing_get_started_step user
    end

    it 'should have current path equal to the Getting Started page' do
      expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
    end

    context 'when clicking the "Start Over" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :get_started))
      end

      it 'redirects the user back to the start of the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.start_over')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
      end
    end

    context 'when clicking the "No, keep going" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :get_started))
      end

      it 'redirects the user back to where the user left off in the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.keep_going')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
      end
    end

    context 'when clicking the "Exit Login.gov" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :get_started))
      end

      it 'redirects the user back to the service provider website' do
        click_button t('idv.cancel.actions.exit', app_name: APP_NAME)
        expect(page).to have_current_path(/\/auth\/result\?/)
      end
    end
  end

  context 'from the "How verifying your identify works" view, and clicking the "Cancel" link' do
    before do
      complete_steps_up_to_inherited_proofing_how_verifying_step user
    end

    it 'should have current path equal to the How Verifying (agreement step) page' do
      expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :agreement))
    end

    context 'when clicking the "Start Over" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :agreement))
      end

      it 'redirects the user back to the start of the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.start_over')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
      end
    end

    context 'when clicking the "No, keep going" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :agreement))
      end

      it 'redirects the user back to where the user left off in the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.keep_going')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :agreement))
      end
    end

    context 'when clicking the "Exit Login.gov" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :agreement))
      end

      it 'redirects the user back to the service provider website' do
        click_button t('idv.cancel.actions.exit', app_name: APP_NAME)
        expect(page).to have_current_path(/\/auth\/result\?/)
      end
    end
  end

  context 'from the "Verify your information..." view, and clicking the "Cancel" link' do
    before do
      complete_steps_up_to_inherited_proofing_verify_your_info_step user
    end

    it 'should have current path equal to the Verify your information (verify_info step) page' do
      expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :verify_info))
    end

    context 'when clicking the "Start Over" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :verify_info))
      end

      it 'redirects the user back to the start of the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.start_over')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :get_started))
      end
    end

    context 'when clicking the "No, keep going" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :verify_info))
      end

      it 'redirects the user back to where the user left off in the Inherited Proofing process' do
        click_button t('inherited_proofing.cancel.actions.keep_going')
        expect(page).to have_current_path(idv_inherited_proofing_step_path(step: :verify_info))
      end
    end

    context 'when clicking the "Exit Login.gov" button from the "Cancel" view' do
      before do
        click_link t('links.cancel')
        expect(page).to have_current_path(idv_inherited_proofing_cancel_path(step: :verify_info))
      end

      it 'redirects the user back to the service provider website' do
        click_button t('idv.cancel.actions.exit', app_name: APP_NAME)
        expect(page).to have_current_path(/\/auth\/result\?/)
      end
    end
  end
end
