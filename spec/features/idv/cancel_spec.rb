require 'rails_helper'

describe 'cancel IdV', :js do
  include IdvStepHelper
  include DocAuthHelper
  include InteractionHelper

  let(:sp) { nil }
  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new(user: user) }

  before do
    start_idv_from_sp(sp)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_agreement_step
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  it 'shows the user a cancellation message with the option to go back to the step' do
    original_path = current_path

    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(current_path).to eq(idv_cancel_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      include(step: 'agreement'),
    )

    click_on t('idv.cancel.actions.keep_going')

    expect(current_path).to eq(original_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation go back',
      include(step: 'agreement'),
    )
  end

  it 'shows the user a cancellation message with the option to restart from the beginning' do
    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(current_path).to eq(idv_cancel_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      include(step: 'agreement'),
    )

    click_on t('idv.cancel.actions.start_over')

    expect(current_path).to eq(idv_doc_auth_welcome_step)
    expect(fake_analytics).to have_logged_event('IdV: start over', include(step: 'agreement'))
  end

  it 'shows a cancellation message with option to cancel and reset idv' do
    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(current_path).to eq(idv_cancel_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      include(step: 'agreement'),
    )

    click_spinner_button_and_wait t('idv.cancel.actions.account_page')

    expect(current_path).to eq(account_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation confirmed',
      include(step: 'agreement'),
    )

    # After visiting /verify, expect to redirect to the first step in the IdV flow.
    visit idv_path
    expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
  end

  context 'when user has recorded proofing components' do
    before do
      complete_agreement_step
      complete_upload_step
      complete_document_capture_step
    end

    it 'includes proofing components in events' do
      click_link t('links.cancel')

      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation visited',
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
        request_came_from: 'idv/doc_auth#show',
        step: 'ssn',
      )

      click_on t('idv.cancel.actions.keep_going')

      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation go back',
        step: 'ssn',
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
      )

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')

      expect(fake_analytics).to have_logged_event(
        'IdV: start over',
        location: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
        step: 'ssn',
      )

      complete_doc_auth_steps_before_ssn_step
      click_link t('links.cancel')

      click_spinner_button_and_wait t('idv.cancel.actions.account_page')

      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation confirmed',
        step: 'ssn',
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
      )
    end
  end

  context 'with an sp' do
    let(:sp) { :oidc }

    it 'shows the user a cancellation message with the option to cancel and reset idv' do
      sp_name = 'Test SP'
      allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).
        and_return(sp_name)

      click_link t('links.cancel')

      expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
      expect(current_path).to eq(idv_cancel_path)
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation visited',
        include(step: 'agreement'),
      )

      click_spinner_button_and_wait t('idv.cancel.actions.exit', app_name: APP_NAME)

      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation confirmed',
        include(step: 'agreement'),
      )

      start_idv_from_sp(sp)
      expect(current_path).to eq(idv_doc_auth_step_path(step: :welcome))
    end
  end
end
