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

  it 'shows the user a cancellation message with the option to go back to the step' do
    expect(page).to have_current_path(idv_agreement_path)
    expect(page).to have_content(t('doc_auth.headings.verify_identity'))

    click_link t('links.cancel')

    expect(page).to have_current_path(idv_cancel_path(step: 'agreement'))
    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'agreement'),
    )

    expect(page).to have_unique_form_landmark_labels

    expect(page).to have_button(t('idv.cancel.actions.start_over'))
    expect(page).to have_button(t('idv.cancel.actions.keep_going'))

    click_on(t('idv.cancel.actions.keep_going'))
    expect(page).to have_current_path(idv_agreement_path)
    expect(page).to have_content(t('doc_auth.headings.lets_go'))
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation go back',
      step: 'agreement',
    )
  end

  it 'shows the user a cancellation message with the option to restart from the beginning' do
    expect(page).to have_content(t('doc_auth.headings.verify_identity'))
    click_link t('links.cancel')

    expect(page).to have_current_path(idv_cancel_path(step: 'agreement'))
    expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'agreement'),
    )

    expect(page).to have_unique_form_landmark_labels

    expect(page).to have_button(t('idv.cancel.actions.start_over'))
    expect(page).to have_button(t('idv.cancel.actions.keep_going'))

    click_on t('idv.cancel.actions.start_over')

    expect(page).to have_current_path(idv_welcome_path)
    expect(page).to have_content(t('headings.identity_verification_intro.what_youll_need'))
    expect(fake_analytics).to have_logged_event(
      'IdV: start over',
      step: 'agreement',
    )
  end

  context 'when user has recorded proofing components' do
    before do
      complete_agreement_step
      expect(page).to have_content(t('doc_auth.headings.how_to_verify'))
      complete_hybrid_handoff_step
      complete_choose_id_type_step
      expect(page).to have_content(t('doc_auth.headings.document_capture'))
      complete_document_capture_step
    end

    it 'includes proofing components in events' do
      expect(page).to have_content(t('doc_auth.info.ssn'))
      click_link t('links.cancel')

      expect(page).to have_current_path(idv_cancel_path(step: 'ssn'))
      expect(page).to have_content(t('idv.cancel.headings.prompt.standard'))
      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation visited',
        proofing_components: { document_check: 'mock',
                               document_type_received: 'drivers_license' },
        request_came_from: 'idv/ssn#show',
        step: 'ssn',
      )

      expect(page).to have_unique_form_landmark_labels

      expect(page).to have_button(t('idv.cancel.actions.start_over'))
      expect(page).to have_button(t('idv.cancel.actions.keep_going'))

      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_content(t('doc_auth.info.ssn'))

      expect(fake_analytics).to have_logged_event(
        'IdV: cancellation go back',
        proofing_components: { document_check: 'mock',
                               document_type_received: 'drivers_license' },
        step: 'ssn',
      )

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_content(t('headings.identity_verification_intro.what_youll_need'))

      expect(fake_analytics).to have_logged_event(
        'IdV: start over',
        proofing_components: { document_check: 'mock',
                               document_type_received: 'drivers_license' },
        step: 'ssn',
      )
    end
  end
end
