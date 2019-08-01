require 'rails_helper'

describe Funnel::Registration::TotalRegisteredCount do
  subject { described_class }

  it 'returns 0' do
    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
  end

  it 'returns 0 if user is not fully registered' do
    user = create(:user)
    user_id = user.id
    Funnel::Registration::Create.call(user_id)

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    Funnel::Registration::AddPassword.call(user_id)

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)

    Funnel::Registration::AddMfa.call(user_id, 'phone')

    expect(Funnel::Registration::TotalRegisteredCount.call).to eq(0)
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
    Funnel::Registration::Create.call(user_id)
    Funnel::Registration::AddPassword.call(user_id)
    Funnel::Registration::AddMfa.call(user_id, 'backup_codes')
  end
end
