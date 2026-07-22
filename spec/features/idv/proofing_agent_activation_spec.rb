require 'rails_helper'

RSpec.describe 'Proofing agent activation', :js do
  include IdvStepHelper

  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
    )
  end
  let(:document_capture_session) do
    create(
      :document_capture_session,
      user: user,
      issuer: service_provider.issuer,
      doc_auth_vendor: Idp::Constants::Vendors::PROOFING_AGENT,
      requested_at: Time.zone.now,
    )
  end
  let(:success) { true }
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:phone_precheck_passed) { true }
  let(:resolution) do
    {
      success: true,
      errors: [],
      exception: nil,
      phone_precheck_passed:,
      context: {
        stages: {
          phone_precheck: { success: phone_precheck_passed, vendor_name: 'AddressMock' },
        },
      },
    }
  end
  let(:aamva_result) do
    {
      success: true,
      errors: [],
      exception: nil,
      mva_exception: nil,
      requested_attributes: {},
      timed_out: false,
      transaction_id: 'abc123',
      vendor_name: 'TestVendor',
      verified_attributes: [:address, :dob, :state_id_number],
    }
  end
  let(:agent_proofing_result) do
    {
      success:,
      resolution:,
      aamva: aamva_result,
      pii:,
      proofing_agent_id: 'proofing-agent-123',
      proofing_location_id: 'location-456',
      correlation_id: 'correlation-789',
      transaction_id: document_capture_session.uuid,
    }
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_enabled).and_return(true)
    document_capture_session.store_agent_proofed_user(agent_proofing_result)
  end

  scenario 'user activates their profile after being proofed by proofing agent' do
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path idv_enter_dob_ssn_path
    complete_idv_enter_dob_ssn_step
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
    expect(page).to have_current_path(account_path)
  end

  context 'when the user enters an incorrect SSN' do
    scenario 'stays on the confirmation page and shows a warning' do
      sign_in_live_with_2fa(user)
      expect(page).to have_current_path idv_enter_dob_ssn_path

      fill_in t('idv.form.ssn_label'), with: '000-00-0000'
      fill_out_dob_form_ok
      click_idv_continue

      expect(page).to have_current_path idv_enter_dob_ssn_path
      expect(page).to have_content t('idv.failure.dob_ssn.warning')
    end
  end

  context 'when the proofing agent session has expired' do
    before do
      document_capture_session.update!(result_id: nil)
    end

    scenario 'user is redirected to the expired page and can restart IDV' do
      sign_in_live_with_2fa(user)
      expect(page).to have_current_path idv_proofing_agent_expired_path

      expect(page).to have_content t('idv.proofing_agent_expired.heading')

      click_button t('idv.proofing_agent_expired.continue')
      expect(page).to have_current_path idv_welcome_path
    end
  end
end
