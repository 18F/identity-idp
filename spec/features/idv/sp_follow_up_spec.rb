require 'rails_helper'
require 'action_account'

RSpec.feature 'returning to an SP after out-of-band proofing' do
  scenario 'receiving an email after entering a verify-by-mail code' do
    post_idv_follow_up_url = 'https://example.com/idv_follow_up'
    initiating_service_provider = create(:service_provider, post_idv_follow_up_url:)
    profile = create(:profile, :verify_by_mail_pending, :with_pii, initiating_service_provider:)
    user = profile.user
    otp = 'ABC123'
    create(
      :gpo_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      created_at: 2.days.ago,
      updated_at: 2.days.ago,
    )

    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)

    fill_in t('idv.gpo.form.otp_label'), with: otp
    click_button t('idv.gpo.form.submit')
    open_last_email
    click_email_link_matching(/return_to_sp\/account_verified_cta/)

    expect(current_url).to eq(post_idv_follow_up_url)
  end

  scenario 'receiving an email after passing fraud review' do
    post_idv_follow_up_url = 'https://example.com/idv_follow_up'
    initiating_service_provider = create(:service_provider, post_idv_follow_up_url:)
    profile = create(:profile, :fraud_review_pending, :with_pii, initiating_service_provider:)
    user = profile.user

    expect(FraudReviewChecker.new(user).fraud_review_pending?).to eq(true)

    review_pass = ActionAccount::ReviewPass.new
    review_pass_config = ScriptBase::Config.new(reason: 'feature-test')
    review_pass.run(args: [user.uuid], config: review_pass_config)

    open_last_email
    click_email_link_matching(/return_to_sp\/account_verified_cta/)

    expect(current_url).to eq(post_idv_follow_up_url)
  end

  context 'after entering a verify-by-mail code' do
    scenario 'clicking on the CTA' do
      post_idv_follow_up_url = 'https://example.com/idv_follow_up'
      initiating_service_provider = create(:service_provider, post_idv_follow_up_url:)
      profile = create(:profile, :verify_by_mail_pending, :with_pii, initiating_service_provider:)
      user = profile.user
      otp = 'ABC123'
      create(
        :gpo_confirmation_code,
        profile: profile,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
        created_at: 2.days.ago,
        updated_at: 2.days.ago,
      )

      sign_in_live_with_2fa(user)

      expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)

      fill_in t('idv.gpo.form.otp_label'), with: otp
      click_button t('idv.gpo.form.submit')
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(idv_sp_follow_up_path)
      click_on t('idv.by_mail.sp_follow_up.connect_account')

      expect(current_url).to eq(post_idv_follow_up_url)
    end

    scenario 'canceling on the CTA and visiting from the account page' do
      post_idv_follow_up_url = 'https://example.com/idv_follow_up'
      initiating_service_provider = create(:service_provider, post_idv_follow_up_url:)
      profile = create(:profile, :verify_by_mail_pending, :with_pii, initiating_service_provider:)
      user = profile.user
      otp = 'ABC123'
      create(
        :gpo_confirmation_code,
        profile: profile,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
        created_at: 2.days.ago,
        updated_at: 2.days.ago,
      )

      sign_in_live_with_2fa(user)

      expect(page).to have_current_path(idv_verify_by_mail_enter_code_path)

      fill_in t('idv.gpo.form.otp_label'), with: otp
      click_button t('idv.gpo.form.submit')
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(idv_sp_follow_up_path)
      click_on t('idv.by_mail.sp_follow_up.go_to_account')

      expect(current_url).to eq(account_url)

      expect(page).to have_content(t('account.index.verification.connect_idv_account.intro'))
      click_on(t('account.index.verification.connect_idv_account.cta'))

      expect(current_url).to eq(post_idv_follow_up_url)
    end
  end
end
