require 'rails_helper'

RSpec.feature 'idv gpo otp verification step' do
  include IdvStepHelper

  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      :verify_by_mail_pending,
      :with_pii,
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
  let(:redirect_after_verification) { nil }
  let(:profile_should_be_active) { true }
  let(:fraud_review_pending) { false }

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(threatmetrix_enabled ? :enabled : :disabled)
  end

  it_behaves_like 'gpo otp verification'

  context 'ThreatMetrix disabled, but we have ThreatMetrix status on proofing component' do
    let(:threatmetrix_enabled) { false }
    let(:profile) do
      create(
        :profile,
        :verify_by_mail_pending,
        :with_pii,
        fraud_pending_reason: 'threatmetrix_review',
      )
    end
    it_behaves_like 'gpo otp verification'
  end

  context 'ThreatMetrix enabled' do
    let(:threatmetrix_enabled) { true }

    context 'ThreatMetrix says "pass"' do
      it_behaves_like 'gpo otp verification'
    end

    context 'ThreatMetrix says "review"' do
      let(:profile_should_be_active) { false }
      let(:profile) do
        create(
          :profile,
          :verify_by_mail_pending,
          :with_pii,
          fraud_pending_reason: 'threatmetrix_review',
        )
      end
      it_behaves_like 'gpo otp verification'
    end

    context 'ThreatMetrix says "reject"' do
      let(:profile_should_be_active) { false }
      let(:profile) do
        create(
          :profile,
          :verify_by_mail_pending,
          :with_pii,
          fraud_pending_reason: 'threatmetrix_reject',
        )
      end
      it_behaves_like 'gpo otp verification'
    end

    context 'No ThreatMetrix result on proofing component' do
      it_behaves_like 'gpo otp verification'
    end
  end

  context 'coming from an "I did not receive my letter" link in a reminder email' do
    it 'renders an alternate ui', :js do
      visit idv_verify_by_mail_enter_code_url(did_not_receive_letter: 1)
      expect(current_path).to eql(new_user_session_path)

      fill_in_credentials_and_submit(user.email, user.password)
      continue_as(user.email, user.password)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq idv_verify_by_mail_enter_code_path
      expect(page).to have_css('h1', text: t('idv.gpo.did_not_receive_letter.title'))
    end
  end

  context 'warning alert banner for gpo letter spammed', :js do
    context 'when gpo letter is not spammed' do
      it 'does not display warning banner' do
        gpo_confirmation_code.update!(updated_at: Time.zone.now - 1.day)
        sign_in_live_with_2fa(user)

        expect(current_path).to eq idv_verify_by_mail_enter_code_path
        expect(page).not_to have_content strip_tags(
          t(
            'idv.gpo.alert_spam_warning_html',
            date_letter_was_sent: I18n.l(
              gpo_confirmation_code.updated_at,
              format: :event_date,
            ),
          ),
        )
      end
    end

    context 'when gpo letter is spammed' do
      it 'displays warning banner' do
        sign_in_live_with_2fa(user)
        expect(current_path).to eq idv_verify_by_mail_enter_code_path
        expect(page).not_to have_content strip_tags(
          t(
            'idv.gpo.alert_spam_warning_html',
            date_letter_was_sent: I18n.l(
              gpo_confirmation_code.updated_at,
              format: :event_date,
            ),
          ),
        )
      end
    end

    context 'multiple gpo codes have been requested' do
      it 'displays warning banner' do
        gpo_confirmation_code.update!(updated_at: Time.zone.now - 1.day)
        latest_gpo_confirmation_code = create(
          :gpo_confirmation_code,
          profile: profile,
          otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
        )
        sign_in_live_with_2fa(user)
        expect(current_path).to eq idv_verify_by_mail_enter_code_path
        expect(page).to have_content strip_tags(
          t(
            'idv.gpo.alert_spam_warning_html',
            date_letter_was_sent: I18n.l(
              latest_gpo_confirmation_code.updated_at,
              format: :event_date,
            ),
          ),
        )
      end
    end
  end

  context 'with gpo personal key after verification' do
    it 'shows the user a personal key after verification' do
      sign_in_live_with_2fa(user)

      expect(current_path).to eq idv_verify_by_mail_enter_code_path
      expect(page).to have_content t('idv.messages.gpo.resend')

      gpo_confirmation_code
      fill_in t('idv.gpo.form.otp_label'), with: otp
      click_button t('idv.gpo.form.submit')

      profile.reload

      expect(page).to have_current_path(idv_personal_key_path)
      expect(page).to have_content(t('account.index.verification.success'))
      expect(page).to have_content(t('step_indicator.flows.idv.get_a_letter'))

      expect(profile.active).to be(true)
      expect(profile.deactivation_reason).to be(nil)

      expect(user.events.account_verified.size).to eq 1
    end
  end

  context 'with gpo feature disabled' do
    before do
      allow(IdentityConfig.store).to receive(:gpo_verification_enabled?).and_return(true)
    end

    it 'allows a user to verify their account for an existing pending profile' do
      sign_in_live_with_2fa(user)

      expect(current_path).to eq idv_verify_by_mail_enter_code_path
      expect(page).to have_content t('idv.messages.gpo.resend')

      gpo_confirmation_code
      fill_in t('idv.gpo.form.otp_label'), with: otp
      click_button t('idv.gpo.form.submit')

      expect(user.events.account_verified.size).to eq 1
      expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
    end
  end

  it 'allows a user to cancel and start over within the banner' do
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_verify_by_mail_enter_code_path
    expect(page).to have_content t('idv.gpo.alert_info')
    expect(page).to have_content t('idv.gpo.wrong_address')
    expect(page).to have_content Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:address1]

    click_on t('idv.gpo.clear_and_start_over')

    expect(current_path).to eq idv_confirm_start_over_path

    click_idv_continue

    expect(current_path).to eq idv_welcome_path
  end

  it 'allows a user to cancel and start over in the footer' do
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_verify_by_mail_enter_code_path
    click_on t('idv.messages.clear_and_start_over')

    expect(current_path).to eq idv_confirm_start_over_path

    click_idv_continue

    expect(current_path).to eq idv_welcome_path
  end
end
