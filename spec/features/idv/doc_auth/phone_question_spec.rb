require 'rails_helper'

RSpec.feature 'phone question step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:analytics_args) do
    {
      step: 'phone_question',
      analytics_id: 'Doc Auth',
      skip_hybrid_handoff: nil,
      irs_reproofing: false,
    }
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_hybrid_handoff_step
    visit(idv_phone_question_url)
  end

  context 'phone question answered' do
    let(:analytics_name) { 'IdV: doc auth phone question submitted' }
    describe '#camera_with_phone' do
      before do
        analytics_args.merge!(camera_phone: true)
      end

      it 'redirects to hybrid handoff if user confirms having phone' do
        click_link t('doc_auth.buttons.have_phone')
        expect(page).to have_current_path(idv_hybrid_handoff_path)
        expect(fake_analytics).to have_logged_event(
          analytics_name,
          hash_including(step: 'phone_question', camera_phone: true),
        )
      end
    end

    describe '#camera_without_phone' do
      before do
        analytics_args.merge!(camera_phone: false)
      end

      it 'redirects to standard document capture if user confirms not having phone' do
        click_link t('doc_auth.phone_question.do_not_have')
        expect(page).to have_current_path(idv_document_capture_path)
        expect(fake_analytics).to have_logged_event(
          analytics_name,
          hash_including(step: 'phone_question', camera_phone: false),
        )
      end
    end
  end

  it 'allows user to cancel identify verification', :js do
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
