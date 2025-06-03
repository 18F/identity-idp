require 'rails_helper'

RSpec.feature 'ThreatMetrix in account creation', :js do
  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')
    allow(IdentityConfig.store)
      .to receive(:lexisnexis_threatmetrix_mock_enabled)
      .and_return(true)
  end

  context 'when tmx is in collect only' do
    before do
      allow(IdentityConfig.store)
        .to receive(:account_creation_device_profiling).and_return(:collect_only)
      allow(IdentityConfig.store)
        .to receive(:account_creation_tmx_processed_percent).and_return(100)
    end
    it 'logs the threatmetrix result once the account is fully registered' do
      user = sign_up_and_set_password

      fake_analytics = FakeAnalytics.new
      expect(page).to have_current_path(authentication_methods_setup_path)
      expect_any_instance_of(AccountCreationThreatMetrixJob).to receive(:analytics).with(user)
        .and_return(fake_analytics)
      select 'Reject', from: :mock_profiling_result
      check t('two_factor_authentication.two_factor_choice_options.phone')
      check t('two_factor_authentication.two_factor_choice_options.backup_code')
      click_continue

      expect(page).to have_current_path(phone_setup_path)
      set_up_mfa_with_valid_phone

      expect(page).to have_current_path(backup_code_setup_path)
      click_continue

      expect(fake_analytics).to have_logged_event(
        :account_creation_tmx_result,
        account_lex_id: 'super-cool-test-lex-id',
        errors: { review_status: ['reject'] },
        response_body: {
          **JSON.parse(LexisNexisFixtures.ddp_success_redacted_response_json),
          'review_status' => 'reject',
        },
        review_status: 'reject',
        session_id: 'super-cool-test-session-id',
        success: true,
        timed_out: false,
        transaction_id: 'ddp-mock-transaction-id-123',
      )
    end
  end

  context 'when tmx is enabled' do
    before do
      allow(IdentityConfig.store)
        .to receive(:account_creation_device_profiling).and_return(:enabled)
      allow(IdentityConfig.store)
        .to receive(:account_creation_tmx_processed_percent).and_return(100)
    end

    context 'when tmx returns a rejected response' do
      it 'logs repsonse and redirects to profiling failed page' do
        user = sign_up_and_set_password

        fake_analytics = FakeAnalytics.new

        expect(page).to have_current_path(authentication_methods_setup_path)
        expect_any_instance_of(AccountCreationThreatMetrixJob).to receive(:analytics).with(user)
          .and_return(fake_analytics)
        select 'Reject', from: :mock_profiling_result
        check t('two_factor_authentication.two_factor_choice_options.phone')
        check t('two_factor_authentication.two_factor_choice_options.backup_code')
        click_continue

        expect(page).to have_current_path(phone_setup_path)
        set_up_mfa_with_valid_phone

        expect(page).to have_current_path(backup_code_setup_path)
        click_continue

        expect(fake_analytics).to have_logged_event(
          :account_creation_tmx_result,
          account_lex_id: 'super-cool-test-lex-id',
          errors: { review_status: ['reject'] },
          response_body: {
            **JSON.parse(LexisNexisFixtures.ddp_success_redacted_response_json),
            'review_status' => 'reject',
          },
          review_status: 'reject',
          session_id: 'super-cool-test-session-id',
          success: true,
          timed_out: false,
          transaction_id: 'ddp-mock-transaction-id-123',
        )

        expect(page).to have_current_path(profiling_failed_path)
      end
    end
  end
end
