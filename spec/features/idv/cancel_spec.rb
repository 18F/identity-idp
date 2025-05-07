require 'rails_helper'

RSpec.describe 'cancel IdV' do
  include IdvStepHelper
  include DocAuthHelper
  include InteractionHelper

  let(:sp) { nil }
  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new(user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics) do |controller|
      fake_analytics.session = controller.session
      fake_analytics
    end
    start_idv_from_sp(sp)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_agreement_step
  end

  it 'shows the user a cancellation message with the option to go back to the step', :js do
    expect(page).to have_content(t('doc_auth.headings.verify_identity'), wait: 0.5)
    original_path = current_path

    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(page).to have_current_path(idv_cancel_path, ignore_query: true)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'agreement'),
    )

    expect(page).to have_unique_form_landmark_labels

    expect(page).to have_button(t('idv.cancel.actions.start_over'))
    expect(page).to have_button(t('idv.cancel.actions.account_page'))
    expect(page).to have_button(t('idv.cancel.actions.keep_going'))

    click_on(t('idv.cancel.actions.keep_going'))
    expect(page).to have_content(t('doc_auth.headings.lets_go'), wait: 0.5)
    expect(page).to have_current_path(original_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation go back',
      step: 'agreement',
    )
  end

  it 'shows the user a cancellation message with the option to restart from the beginning' do
    expect(page).to have_content(t('doc_auth.headings.verify_identity'), wait: 0.5)
    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(page).to have_current_path(idv_cancel_path, ignore_query: true)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'agreement'),
    )

    expect(page).to have_unique_form_landmark_labels

    expect(page).to have_button(t('idv.cancel.actions.start_over'))
    expect(page).to have_button(t('idv.cancel.actions.account_page'))
    expect(page).to have_button(t('idv.cancel.actions.keep_going'))

    click_on t('idv.cancel.actions.start_over')

    expect(page).to have_content(t('doc_auth.instructions.getting_started'), wait: 0.5)
    expect(page).to have_current_path(idv_welcome_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: start over',
      step: 'agreement',
    )
  end

  it 'shows a cancellation message with option to cancel and reset idv', :js do
    expect(page).to have_content(t('doc_auth.headings.verify_identity'), wait: 0.5)
    click_link t('links.cancel')

    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(page).to have_current_path(idv_cancel_path, ignore_query: true)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'agreement'),
    )

    expect(page).to have_unique_form_landmark_labels

    expect(page).to have_button(t('idv.cancel.actions.start_over'))
    expect(page).to have_button(t('idv.cancel.actions.account_page'))
    expect(page).to have_button(t('idv.cancel.actions.keep_going'))

    click_spinner_button_and_wait t('idv.cancel.actions.account_page')

    expect(page).to have_current_path(account_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation confirmed',
      step: 'agreement',
    )

    # After visiting /verify, expect to redirect to the first step in the IdV flow.
    visit idv_path
    expect(page).to have_content(t('doc_auth.instructions.getting_started'), wait: 0.5)
    expect(page).to have_current_path(idv_welcome_path)
  end

  context 'when user has recorded proofing components' do
    before do
      complete_agreement_step
      expect(page).to have_content(t('doc_auth.headings.hybrid_handoff'), wait: 0.5)
      complete_hybrid_handoff_step
      expect(page).to have_content(t('doc_auth.headings.document_capture'), wait: 0.5)
      complete_document_capture_step
    end

    it 'includes proofing components in events', :js do
      expect(page).to have_content(t('doc_auth.info.ssn'), wait: 0.5)
      click_link t('links.cancel')

      expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation visited',
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
        request_came_from: 'idv/ssn#show',
        step: 'ssn',
      )

      expect(page).to have_unique_form_landmark_labels

      expect(page).to have_button(t('idv.cancel.actions.start_over'))
      expect(page).to have_button(t('idv.cancel.actions.account_page'))
      expect(page).to have_button(t('idv.cancel.actions.keep_going'))

      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_content(t('doc_auth.info.ssn'), wait: 0.5)

      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation go back',
        proofing_components: { document_check: 'mock', document_type: 'state_id' },
        step: 'ssn',
      )

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_content(t('doc_auth.instructions.getting_started'), wait: 0.5)

      expect(fake_analytics).to have_logged_event(
        'IdV: start over',
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

    it 'shows the user a cancellation message with the option to cancel and reset idv', :js do
      sp_name = 'Test SP'
      allow_any_instance_of(ServiceProviderSession).to receive(:sp_name)
        .and_return(sp_name)

      click_link t('links.cancel')

      expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
      expect(page).to have_current_path(idv_cancel_path, ignore_query: true)
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation visited',
        hash_including(step: 'agreement'),
      )

      expect(page).to have_button(t('idv.cancel.actions.start_over'))
      expect(page).to have_button(t('idv.cancel.actions.exit', app_name: APP_NAME))
      expect(page).to have_button(t('idv.cancel.actions.keep_going'))

      expect(page).to have_unique_form_landmark_labels

      click_spinner_button_and_wait t('idv.cancel.actions.exit', app_name: APP_NAME)

      expect(page).to have_current_path(
        'http://localhost:7654/auth/result',
        url: true,
        ignore_query: true,
      )
      expect(current_url).to start_with('http://localhost:7654/auth/result?error=access_denied')
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation confirmed',
        step: 'agreement',
      )

      start_idv_from_sp(sp)
      expect(page).to have_content(t('doc_auth.instructions.getting_started'), wait: 0.5)
      expect(page).to have_current_path(idv_welcome_path)
    end
  end
end
