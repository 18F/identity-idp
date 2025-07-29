require 'rails_helper'

RSpec.describe Funnel::Registration::TotalRegisteredCount do
  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new }
  let(:threatmetrix_attrs) do
    {
      user_id: user.id,
      request_ip: Faker::Internet.ip_v4_address,
      threatmetrix_session_id: 'test-session',
      email: user.email,
      in_ab_test_bucket: true,
      in_account_creation_flow: true,
    }
  end
  subject { described_class }

  it 'returns 0' do
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
  end

  it 'returns 0 until the user is fully registered' do
    user_id = user.id
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    Funnel::Registration::AddMfa.call(user_id, 'phone', analytics, threatmetrix_attrs)

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(1)
  end

  it 'returns 1 when a user is fully registered' do
    register_user

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(1)
  end

  it 'returns 2' do
    register_user
    register_user

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(2)
  end

  def register_user
    user = create(:user)
    user_id = user.id
    Funnel::Registration::AddMfa.call(user_id, 'backup_codes', analytics, threatmetrix_attrs)
  end
end
