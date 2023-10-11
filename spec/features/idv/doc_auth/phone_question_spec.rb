require 'rails_helper'

RSpec.feature 'phone question step', :js do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_hybrid_handoff_step
    visit(idv_phone_question_url)
  end

  it 'contains phone question header' do
    expect(page).to have_content(t('doc_auth.headings.phone_question'))
  end

  it 'contains option to confirm having phone' do
    expect(page).to have_content(t('doc_auth.buttons.have_phone'))
  end

  it 'contains option to confirm not having phone' do
    expect(page).to have_content(t('doc_auth.phone_question.do_not_have'))
  end

  it 'allows user to cancel identify verification' do
    click_link t('links.cancel')
    expect(page).to have_current_path(idv_cancel_path(step: 'phone_question'))

    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      hash_including(step: 'phone_question'),
    )

    click_spinner_button_and_wait t('idv.cancel.actions.account_page')

    expect(current_path).to eq(account_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation confirmed',
      hash_including(step: 'phone_question'),
    )
  end
end
