require 'rails_helper'

feature 'idv gpo confirm cancel' do
  include IdvStepHelper
  include DocAuthHelper

  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      deactivation_reason: :gpo_verification_pending,
      pii: { ssn: '123-45-6789', dob: '1970-01-01' },
      fraud_review_pending_at: nil,
      fraud_rejection_at: nil,
    )
  end
  let(:gpo_confirmation_code) do
    create(
      :gpo_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )
  end
  let(:user) { profile.user }

  before do
    sign_in_live_with_2fa(user)
  end

  it 'begins on the gpo code entry page' do
    expect(current_path).to eq idv_gpo_verify_path
  end

  it 'goes to the confirm screen when cancel is clicked' do
    click_on t('idv.messages.clear_and_start_over')

    expect(current_path).to eq idv_gpo_confirm_cancel_path
  end

  it 'clears user data and returns to welcome screen after confirming' do
    click_on t('idv.messages.clear_and_start_over')
    click_idv_continue

    expect(current_path).to eq idv_doc_auth_welcome_step
  end
end
