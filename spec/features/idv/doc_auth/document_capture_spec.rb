require 'rails_helper'

feature 'doc auth document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:doc_auth_enable_presigned_s3_urls) { false }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  before do
    allow(IdentityConfig.store).to receive(:doc_auth_document_capture_controller_enabled).
      and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).
      and_return(doc_auth_enable_presigned_s3_urls)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)

    visit_idp_from_oidc_sp_with_ial2

    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_document_capture_step
  end

  it 'shows the new DocumentCapture page for desktop standard flow' do
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_document_capture_url)

    expect(page).to have_content(t('doc_auth.headings.document_capture'))
    expect(page).to have_content(t('step_indicator.flows.idv.verify_id'))

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth document_capture visited',
      flow_path: 'standard',
      step: 'document_capture',
      step_count: 1,
      analytics_id: 'Doc Auth',
      irs_reproofing: false,
      acuant_sdk_upgrade_ab_test_bucket: :default,
    )
  end
end
