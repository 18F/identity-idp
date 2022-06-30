require 'rails_helper'

describe Funnel::Registration::AddMfa do
  subject { described_class }

  let(:user_id) do
    user = create(:user)
    user_id = user.id
    Funnel::Registration::Create.call(user_id)
    user_id
  end
  let(:funnel) { RegistrationLog.all.first }

  it 'adds an 1st mfa' do
    subject.call(user_id, 'phone')

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.first_mfa_at).to be_present
  end

  it 'adds a 2nd mfa' do
    subject.call(user_id, 'phone')
    subject.call(user_id, 'backup_codes')

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.first_mfa_at).to be_present
    expect(funnel.second_mfa).to eq('backup_codes')
  end

  it 'does not add a 3rd mfa' do
    subject.call(user_id, 'phone')
    subject.call(user_id, 'backup_codes')
    subject.call(user_id, 'auth_app')

    expect(funnel.first_mfa).to eq('phone')
    expect(funnel.second_mfa).to eq('backup_codes')
  end
end
