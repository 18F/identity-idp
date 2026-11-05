require 'rails_helper'

RSpec.describe AccountRecovery::RequestAnalyticsAttributes do
  subject(:attributes) { described_class.new(user: user, now: now).call }

  let(:now) { Time.zone.now }
  let(:user) { create(:user, :fully_registered, confirmed_at: now - 400.days) }

  around do |example|
    freeze_time { example.run }
  end

  it 'reports the account age in whole days since confirmation' do
    expect(attributes[:account_age_in_days]).to eq(400)
  end

  it 'reports a nil account age for an unconfirmed account' do
    user.update!(confirmed_at: nil)

    expect(attributes[:account_age_in_days]).to be_nil
  end

  it 'reports enabled MFA method counts by type' do
    create(:phone_configuration, user: user)
    create(:auth_app_configuration, user: user)

    expect(attributes[:enabled_mfa_methods_count]).to eq(3)
    expect(attributes[:mfa_method_counts]).to eq(phone: 2, auth_app: 1)
  end

  it 'reports the age of the newest configuration of each method type' do
    user.phone_configurations.first.update!(created_at: now - 300.days)
    create(:phone_configuration, user: user, created_at: now - 3.days)
    create(:auth_app_configuration, user: user, created_at: now - 45.days)

    expect(attributes[:mfa_method_ages_in_days]).to eq(phone: 3, auth_app: 45)
  end

  it 'excludes methods that are not enabled for MFA' do
    create(:phone_configuration, user: user, mfa_enabled: false, created_at: now - 1.day)

    expect(attributes[:mfa_method_ages_in_days]).to eq(phone: 0)
    expect(attributes[:mfa_method_counts]).to eq(phone: 1)
  end

  it 'reports days since the most recent fully authenticated sign-in' do
    create(:event, user: user, event_type: :sign_in_after_2fa, created_at: now - 90.days)
    create(:event, user: user, event_type: :sign_in_after_2fa, created_at: now - 10.days)
    create(:event, user: user, event_type: :sign_in_before_2fa, created_at: now - 1.day)

    expect(attributes[:days_since_last_full_sign_in]).to eq(10)
  end

  it 'does not use another user’s sign-ins' do
    create(:event, event_type: :sign_in_after_2fa, created_at: now - 1.day)

    expect(attributes[:days_since_last_full_sign_in]).to be_nil
  end

  it 'reports nil when the user has never fully signed in' do
    expect(attributes[:days_since_last_full_sign_in]).to be_nil
  end

  it 'marks phone keypaths as non-PII method names' do
    expect(attributes[:pii_like_keypaths]).to contain_exactly(
      [:mfa_method_counts, :phone],
      [:mfa_method_ages_in_days, :phone],
    )
  end
end
