require 'rails_helper'

RSpec.feature 'idv enter letter code step', allowed_extra_analytics: [:*] do
  include IdvStepHelper

  let(:otp) { 'ABC123' }
  let(:wrong_otp) { 'XYZ456' }
  let(:profile) do
    create(
      :profile,
      :verify_by_mail_pending,
      :with_pii,
    )
  end
  let!(:gpo_confirmation_code) do
    create(
      :gpo_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      created_at: 2.days.ago,
      updated_at: 2.days.ago,
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

  it_behaves_like 'verification code entry'

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
    it_behaves_like 'verification code entry'
  end

  context 'ThreatMetrix enabled' do
    let(:threatmetrix_enabled) { true }

    context 'ThreatMetrix says "pass"' do
      it_behaves_like 'verification code entry'
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
      it_behaves_like 'verification code entry'
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
      it_behaves_like 'verification code entry'
    end

    context 'No ThreatMetrix result on proofing component' do
      it_behaves_like 'verification code entry'
    end
  end

  it 'renders an error with the enter code ui if an incorrect code is entered' do
    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    continue_as(user.email, user.password)
    uncheck(t('forms.messages.remember_device'))
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(current_path).to eq idv_verify_by_mail_enter_code_path
    expect(page).to have_css('h1', text: t('idv.gpo.title'))

    fill_in t('idv.gpo.form.otp_label'), with: 'incorrect1'
    click_button t('idv.gpo.form.submit')

    expect(page).to have_css('h1', text: t('idv.gpo.title'))
    expect(page).to have_content(t('errors.messages.confirmation_code_incorrect'))
  end

  context 'coming from an "I did not receive my letter" link in a reminder email' do
    it 'renders an alternate ui that remains after failed submission', :js do
      visit idv_verify_by_mail_enter_code_url(did_not_receive_letter: 1)
      verify_no_rate_limit_banner
      expect(current_path).to eql(new_user_session_path)

      fill_in_credentials_and_submit(user.email, user.password)
      continue_as(user.email, user.password)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq idv_verify_by_mail_enter_code_path
      expect(page).to have_css('h1', text: t('idv.gpo.did_not_receive_letter.title'))

      fill_in t('idv.gpo.form.otp_label'), with: 'incorrect1'
      click_button t('idv.gpo.form.submit')

      expect(current_path).to eq idv_verify_by_mail_enter_code_path
      expect(page).to have_css('h1', text: t('idv.gpo.did_not_receive_letter.title'))
      expect(page).to have_content(t('errors.messages.confirmation_code_incorrect'))
    end
  end

  context 'has gpo_confirmation_code sent before present day' do
    before do
      gpo_confirmation_code.update!(updated_at: Time.zone.now - 1.day)
    end
    context 'with gpo personal key after verification' do
      it 'shows the user a personal key after verification' do
        sign_in_live_with_2fa(user)

        expect(current_path).to eq idv_verify_by_mail_enter_code_path
        verify_no_rate_limit_banner
        expect(page).to have_content t('idv.messages.gpo.resend')

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

        verify_no_rate_limit_banner
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
      verify_no_rate_limit_banner

      click_on t('idv.gpo.clear_and_start_over')

      expect(current_path).to eq idv_confirm_start_over_path

      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end
  end

  it 'allows a user to cancel and start over in the accordion' do
    another_gpo_confirmation_code = create(
      :gpo_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_verify_by_mail_enter_code_path
    verify_rate_limit_banner_present(another_gpo_confirmation_code.updated_at)

    click_on t('idv.gpo.address_accordion.cta_link')

    expect(current_path).to eq idv_confirm_start_over_path

    click_idv_continue

    expect(current_path).to eq idv_welcome_path
  end

  context 'user is rate limited', :js do
    before do
      sign_in_live_with_2fa(user)

      (RateLimiter.max_attempts(:verify_gpo_key) - 1).times do
        fill_in t('idv.gpo.form.otp_label'), with: wrong_otp
        click_button t('idv.gpo.form.submit')
      end
    end

    it 'redirects to rate limited page' do
      fill_in t('idv.gpo.form.otp_label'), with: wrong_otp
      click_button t('idv.gpo.form.submit')

      expect(current_path).to eq(idv_enter_code_rate_limited_path)
    end
  end

  context 'user cancels idv from enter code page after getting rate limited', :js do
    it 'redirects to welcome page' do
      RateLimiter.new(user: user, rate_limit_type: :proof_address).increment_to_limited!

      sign_in_live_with_2fa(user)

      click_on t('idv.gpo.address_accordion.title')
      click_on t('idv.gpo.address_accordion.cta_link')
      expect(current_path).to eq idv_confirm_start_over_path
      click_idv_continue

      expect(current_path).to eq idv_welcome_path
    end
  end

  context 'when the letter is too old' do
    let(:code_sent_at) { (IdentityConfig.store.usps_confirmation_max_days + 1).days.ago }

    before do
      user.gpo_verification_pending_profile.update(
        created_at: code_sent_at,
        updated_at: code_sent_at,
      )

      gpo_confirmation_code.update(
        code_sent_at: code_sent_at,
        created_at: code_sent_at,
        updated_at: code_sent_at,
      )

      sign_in_live_with_2fa(user)
    end

    it 'shows a warning message and does not allow the user to request another letter' do
      verify_rate_limit_banner_present(code_sent_at)
      expect(page).not_to have_content t('idv.messages.gpo.resend')
    end
  end

  def verify_no_rate_limit_banner
    expect(page).not_to have_content(
      t(
        'idv.gpo.alert_rate_limit_warning_html',
        date_letter_was_sent: I18n.l(
          Time.zone.now,
          format: :event_date,
        ),
      ).split('<strong>').first,
    )
  end

  def verify_rate_limit_banner_present(code_sent_at = Time.zone.now)
    expect(page).to have_content strip_tags(
      t(
        'idv.gpo.alert_rate_limit_warning_html',
        date_letter_was_sent: I18n.l(
          code_sent_at,
          format: :event_date,
        ),
      ),
    )
  end
end
