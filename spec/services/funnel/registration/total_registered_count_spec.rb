require 'rails_helper'

describe Funnel::Registration::TotalRegisteredCount do
  let(:analytics) { FakeAnalytics.new }
  subject { described_class }

  it 'returns 0' do
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
  end

  it 'returns 0 until the user is fully registered' do
    user = create(:user)
    user_id = user.id
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    Funnel::Registration::AddMfa.call(user_id, 'phone', analytics)

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
    Funnel::Registration::AddMfa.call(user_id, 'backup_codes', analytics)
  end
end
