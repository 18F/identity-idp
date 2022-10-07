require 'rails_helper'

describe Funnel::Registration::AddMfa do
  let(:analytics) { FakeAnalytics.new }
  subject { described_class }

  let(:user_id) do
    user = create(:user)
    user.id
  end
  let(:funnel) { RegistrationLog.all.first }

  it 'adds an 1st mfa' do
    subject.call(user_id, 'phone', analytics)

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.first_mfa_at).to be_present
  end

  it 'adds a 2nd mfa' do
    subject.call(user_id, 'phone', analytics)
    subject.call(user_id, 'backup_codes', analytics)

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.first_mfa_at).to be_present
    expect(funnel.second_mfa).to eq('backup_codes')
  end

  it 'does not add a 3rd mfa' do
    subject.call(user_id, 'phone', analytics)
    subject.call(user_id, 'backup_codes', analytics)
    subject.call(user_id, 'auth_app', analytics)

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.second_mfa).to eq('backup_codes')
  end
end
