require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include IdvHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  before(:all) do
    @user = user_with_2fa
    @fake_analytics = FakeAnalytics.new
    @sp_name = 'Test SP'
  end

  after(:all) do
    @user.destroy
    @fake_analytics = ''
    @sp_name = ''
  end

  context 'standard desktop flow' do
    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_separate_pages_enabled).and_return(true)
      visit_idp_from_oidc_sp_with_ial2(biometric_comparison_required: true)
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end

    context 'when doc auth seperated pages flow is enabled and selfie is required',
            allow_browser_log: true do
      it '1st page does not have selfie tips even when selfie is required' do
        expect(page).to have_current_path(idv_document_capture_url)
        expect(page).not_to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
      end
      it 'after uploading ID, clicking continue takes user to the selfie capture step' do
        attach_images
        continue_doc_auth_form
        expect(page).to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
      end
      it 'user can go through verification uploading ID and selfie on seprerate pages' do
        attach_images
        continue_doc_auth_form
        expect(page).to have_content(t('doc_auth.tips.document_capture_selfie_text1'))
        attach_selfie
        submit_images
        expect(page).to have_content(t('doc_auth.headings.capture_complete'))
      end
      it 'initial verification failure allows user to resubmit all images in 1 page' do
        attach_images(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_multiple_doc_auth_failures_both_sides.yml'
          ),
        )
        continue_doc_auth_form
        attach_selfie(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_forces_error.yml'
          ),
        )
        submit_images
        expect(page).to have_content(t('doc_auth.errors.rate_limited_heading'))
        click_try_again
        expect(page).to have_content(t('doc_auth.headings.review_issues'))
        attach_liveness_images
        submit_images
        expect(page).to have_content(t('doc_auth.headings.capture_complete'))
      end
    end
  end
end
