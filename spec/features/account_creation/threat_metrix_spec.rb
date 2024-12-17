require 'rails_helper'

RSpec.feature 'ThreatMetrix in account creation', :js do
  before do
    allow(IdentityConfig.store).to receive(:account_creation_device_profiling).and_return(:enabled)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')
  end

  it 'logs the threatmetrix result once the account is fully registered' do
    visit root_url
    click_on t('links.create_account')
    fill_in t('forms.registration.labels.email'), with: Faker::Internet.email
    check t('sign_up.terms', app_name: APP_NAME)
    click_button t('forms.buttons.submit.default')
    user = confirm_last_user
    set_password(user)
    fake_analytics = FakeAnalytics.new
    expect_any_instance_of(AccountCreationThreatMetrixJob).to receive(:analytics).with(user)
      .and_return(fake_analytics)
    select_2fa_option('backup_code')
    select 'Reject', from: :mock_profiling_result
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
