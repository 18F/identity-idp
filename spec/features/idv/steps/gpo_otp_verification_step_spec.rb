require 'rails_helper'

feature 'idv gpo otp verification step', :js do
  include IdvStepHelper

  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      deactivation_reason: :gpo_verification_pending,
      pii: { ssn: '123-45-6789', dob: '1970-01-01' },
      proofing_components: {
        threatmetrix: threatmetrix_enabled,
        threatmetrix_review_status: threatmetrix_review_status,
      },
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

  let(:threatmetrix_enabled) { false }
  let(:threatmetrix_review_status) { nil }

  it 'prompts for one-time code at sign in' do
    sign_in_and_enter_otp

    expect(user.events.account_verified.size).to eq 1
    expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
  end

  it 'renders an error for an expired GPO OTP' do
    sign_in_live_with_2fa(user)

    gpo_confirmation_code.update(code_sent_at: 11.days.ago)
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')

    expect(current_path).to eq idv_gpo_verify_path
    expect(page).to have_content t('errors.messages.gpo_otp_expired')

    user.reload

    expect(user.events.account_verified.size).to eq 0
    expect(user.active_profile).to be_nil
  end

  it 'allows a user to resend a letter' do
    resend_letter
  end

  context 'with gpo feature disabled' do
    before do
      allow(IdentityConfig.store).to receive(:enable_gpo_verification?).and_return(true)
    end

    it 'allows a user to verify their account for an existing pending profile' do
      sign_in_live_with_2fa(user)

      expect(current_path).to eq idv_gpo_verify_path
      expect(page).to have_content t('idv.messages.gpo.resend')

      gpo_confirmation_code
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(user.events.account_verified.size).to eq 1
      expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
    end
  end

  context 'ThreatMetrix enabled' do
    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_enabled).and_return(threatmetrix_enabled)
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_required_to_verify).
        and_return(threatmetrix_enabled)
      allow(IdentityConfig.store).to receive(:proofing_device_profiling_decisioning_enabled).
        and_return(threatmetrix_enabled)
    end

    context 'ThreatMetrix evaluates as "pass"' do
      let(:threatmetrix_review_status) { 'pass' }
      it 'redirects to account page after OTP' do
        sign_in_and_enter_otp
      end
      it 'allows requesting a new letter' do
        resend_letter
      end
    end

    context 'ThreatMetrix evaluates as "review"' do
      let(:threatmetrix_review_status) { 'review' }
      it 'redirects to account page after OTP' do
        sign_in_and_enter_otp
      end
      it 'allows requesting a new letter' do
        resend_letter
      end
    end

    context 'ThreatMetrix evaluates as "reject"' do
      let(:threatmetrix_review_status) { 'reject' }
      it 'redirects to sad face after OTP' do
        binding.pry
        sign_in_and_enter_otp
        expect(page).to have_current_path(idv_come_back_later_path)
      end
      it 'allows requesting a new letter' do
        resend_letter
      end
    end

    context 'ThreatMetrix evaluates as nil' do
      let(:threatmetrix_review_status) { nil }
      it 'redirects to account page after OTP' do
        sign_in_and_enter_otp
      end
      it 'allows requesting a new letter' do
        resend_letter
      end
    end
  end

  def sign_in_and_enter_otp
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_gpo_verify_path
    expect(page).to have_content t('idv.messages.gpo.resend')

    gpo_confirmation_code
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')
  end

  def resend_letter
    allow(Base32::Crockford).to receive(:encode).and_return(otp)

    sign_in_live_with_2fa(user)

    expect(GpoConfirmation.count).to eq(0)
    expect(GpoConfirmationCode.count).to eq(0)
    click_on t('idv.messages.gpo.resend')

    expect_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))

    click_on t('idv.buttons.mail.resend')

    expect(GpoConfirmation.count).to eq(1)
    expect(GpoConfirmationCode.count).to eq(1)
    expect(current_path).to eq idv_come_back_later_path

    confirmation_code = GpoConfirmationCode.first
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)

    expect(confirmation_code.otp_fingerprint).to eq(otp_fingerprint)
    expect(confirmation_code.profile).to eq(profile)
  end
end
