require 'rails_helper'

feature 'Existing USer Non Restricted Method Required' do
  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include SpAuthHelper

  let(:enforcement_date) { Time.zone.today - 6.days }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
    allow(IdentityConfig.store).to receive(:kantara_2fa_phone_existing_user_restriction).
      and_return(true)
    allow(IdentityConfig.store).to receive(:kantara_restriction_enforcement_date).
      and_return(enforcement_date.to_datetime)
  end

  context 'signing in' do
    context 'when its past enforcement date' do
      scenario 'user skips and is allowed to skip once' do
        user = create(:user, :signed_up, :with_phone)
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(current_url).to eq login_additional_mfa_required_url
        expect(page).to have_content(t('mfa.additional_mfa_required.non_restricted_required_info'))

        click_on(t('mfa.skip_once'))
        expect(current_url).to eq account_url
        user.reload
        expect(user.non_restricted_mfa_required_prompt_skip_date).
          to eq Time.zone.today
      end

      scenario 'user can go add second method after redirecting to additional mfa required page' do
        user = create(:user, :signed_up, :with_phone)
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(current_url).to eq login_additional_mfa_required_url
        expect(page).to have_content(t('mfa.additional_mfa_required.non_restricted_required_info'))

        click_on(t('mfa.additional_mfa_required.button'))
        expect(page).to have_current_path(second_mfa_setup_path)
      end

      scenario "user has already skipped, can't find skip link" do
        user = create(:user, :signed_up, :with_phone)
        user.non_restricted_mfa_required_prompt_skip_date = Time.zone.today
        user.save!
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(current_url).to eq login_additional_mfa_required_url
        expect(page).to have_content(t('mfa.additional_mfa_required.non_restricted_required_info'))

        expect(page).not_to have_content(t('mfa.skip_once'))
        expect(page).not_to have_content(t('mfa.skip'))

        click_on(t('mfa.additional_mfa_required.button'))
        expect(page).to have_current_path(second_mfa_setup_path)
      end
    end

    context 'when its before enforcement date' do
      let(:enforcement_date) { Time.zone.today + 5.days }
      scenario 'and user can skip' do
        user = create(:user, :signed_up, :with_phone)
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(current_url).to eq login_additional_mfa_required_url
        expect(page).to have_content(
          t(
            'mfa.additional_mfa_required.info',
            date: I18n.l(
              enforcement_date.to_datetime,
              format: :event_date,
            ),
          ),
        )

        click_on(t('mfa.skip'))
        expect(current_url).to eq account_url
        user.reload
        expect(user.non_restricted_mfa_required_prompt_skip_date).
          not_to eq Time.zone.today
      end

      scenario 'user can go to second method page' do
        user = create(:user, :signed_up, :with_phone)
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(current_url).to eq login_additional_mfa_required_url
        expect(page).to have_content(
          t(
            'mfa.additional_mfa_required.info',
            date: I18n.l(
              enforcement_date.to_datetime,
              format: :event_date,
            ),
          ),
        )

        click_on(t('mfa.additional_mfa_required.button'))
        expect(page).to have_current_path(second_mfa_setup_path)
      end
    end
  end
end
