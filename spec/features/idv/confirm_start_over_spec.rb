require 'rails_helper'

RSpec.feature 'idv gpo confirm start over', js: true, allowed_extra_analytics: [:*] do
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
  let!(:gpo_confirmation_code) do
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
  end

  context 'user decides to start over from request letter page' do
    it 'allows user to start over' do
      start_idv_from_sp
      complete_idv_steps_before_gpo_step
      click_on t('idv.messages.gpo.start_over_link_text')

      expect(current_path).to eq idv_confirm_start_over_before_letter_path
      expect(page).to have_content(t('idv.cancel.description.gpo.start_over_new_address'))
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_phone_or_address'))
      expect(fake_analytics).to have_logged_event(:idv_gpo_confirm_start_over_before_letter_visited)
      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end
  end

  context 'user decides to start over after requesting a letter' do
    before do
      sign_in_live_with_2fa(user)
    end

    it 'can cancel from confirmation screen' do
      expect(current_path).to eq idv_verify_by_mail_enter_code_path

      click_on t('idv.gpo.address_accordion.title')
      click_on t('idv.gpo.address_accordion.cta_link')

      expect(current_path).to eq idv_confirm_start_over_path
      expect(page).to have_content(t('idv.cancel.description.gpo.start_over'))
      expect_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
      expect(fake_analytics).to have_logged_event('IdV: gpo confirm start over visited')

      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end

    it 'can return back to verify screen from confirm screen' do
      click_on t('idv.gpo.address_accordion.title')
      click_on t('idv.gpo.address_accordion.cta_link')
      click_on t('forms.buttons.back')

      expect(fake_analytics).to have_logged_event('IdV: gpo confirm start over visited')
      expect(current_path).to eq idv_verify_by_mail_enter_code_path
    end
  end
end
