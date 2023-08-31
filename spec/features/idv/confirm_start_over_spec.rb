require 'rails_helper'

RSpec.feature 'idv gpo confirm start over', js: true do
  include IdvStepHelper
  include DocAuthHelper

  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      pii: { ssn: '123-45-6789', dob: '1970-01-01' },
      fraud_review_pending_at: nil,
      fraud_rejection_at: nil,
      gpo_verification_pending_at: 1.day.ago,
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
  let(:fake_analytics) { FakeAnalytics.new(user: user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    sign_in_live_with_2fa(user)
  end

  it 'can cancel from confirmation screen' do
    expect(current_path).to eq idv_gpo_verify_path

    click_on t('idv.messages.clear_and_start_over')

    expect(current_path).to eq idv_confirm_start_over_path
    expect(fake_analytics).to have_logged_event('IdV: gpo confirm start over visited')

    click_idv_continue

    expect(current_path).to eq idv_doc_auth_welcome_step
  end

  it 'can return back to verify screen from confirm screen' do
    click_on t('idv.messages.clear_and_start_over')
    click_on t('forms.buttons.back')

    expect(fake_analytics).to have_logged_event('IdV: gpo confirm start over visited')
    expect(current_path).to eq idv_gpo_verify_path
  end
end
