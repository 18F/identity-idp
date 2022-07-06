require 'rails_helper'

feature 'doc auth link sent step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:user) { sign_in_and_2fa_user }
  let(:doc_capture_polling_enabled) { false }

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).
      and_return(doc_capture_polling_enabled)
    user
    complete_doc_auth_steps_before_link_sent_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    expect(page).to have_content(t('doc_auth.headings.text_message'))
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.verify_id'),
    )
  end

  it 'proceeds to the next page with valid info' do
    mock_doc_captured(user.id)
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'proceeds to the next page if the user does not have a phone' do
    user = create(:user, :with_authentication_app, :with_piv_or_cac)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_link_sent_step
    mock_doc_captured(user.id)
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not proceed to the next page if the capture flow is incomplete' do
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  it 'does not proceed to the next page if the capture flow is unsuccessful' do
    mock_doc_captured(user.id, DocAuth::Response.new(success: false))

    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  context 'cancelled' do
    before do
      document_capture_session = user.document_capture_sessions.last
      document_capture_session.cancelled_at = Time.zone.now
      document_capture_session.save!
    end

    it 'redirects to before hybrid flow started and shows alert text' do
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_upload_step)
      expect(page).to have_css(
        '.usa-alert--error',
        text: t('errors.doc_auth.document_capture_cancelled'),
      )
    end
  end

  shared_examples 'with doc capture polling enabled' do
    metadata[:js] = true
    let(:doc_capture_polling_enabled) { true }

    it 'automatically advances when the mobile flow is complete' do
      expect(page).to_not have_css 'meta[http-equiv="refresh"]', visible: false
      expect(page).to_not have_button(t('forms.buttons.continue'))
      expect(page).to_not have_content(t('doc_auth.info.link_sent_complete_no_polling'))
      expect(page).to have_content(t('doc_auth.info.link_sent_complete_polling'))

      mock_doc_captured(user.id)

      expect(page).to have_content(t('doc_auth.headings.ssn'), wait: 6)
      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end
  end

  shared_examples 'with doc capture polling disabled' do
    let(:doc_capture_polling_enabled) { false }

    context 'clicks back link' do
      before do
        click_doc_auth_back_link

        visit idv_doc_auth_link_sent_step
      end

      it 'redirects to send link step' do
        expect(page).to have_current_path(idv_doc_auth_send_link_step)
      end
    end

    it 'refreshes page 4x with meta refresh extending timeout by 40 min and can start over' do
      4.times do
        expect(page).to have_css 'meta[http-equiv="refresh"]', visible: false
        visit idv_doc_auth_link_sent_step
      end
      expect(page).to_not have_css 'meta[http-equiv="refresh"]', visible: false

      click_doc_auth_back_link
      click_doc_auth_back_link
      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      complete_doc_auth_steps_before_link_sent_step
      expect(page).to have_css 'meta[http-equiv="refresh"]', visible: false
    end
  end

  it_behaves_like 'with doc capture polling enabled'
  it_behaves_like 'with doc capture polling disabled'
end
