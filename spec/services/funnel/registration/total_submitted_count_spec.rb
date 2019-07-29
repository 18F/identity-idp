require 'rails_helper'

describe Funnel::Registration::TotalSubmittedCount do
  subject { described_class }

  it 'returns 0' do
    expect(subject.call).to eq(0)
  end

  it 'returns 1' do
    user = create(:user)
    Funnel::Registration::Create.call(user.id)

    expect(subject.call).to eq(1)
  end

  it 'returns 2' do
    Funnel::Registration::Create.call(create(:user).id)
    Funnel::Registration::Create.call(create(:user).id)

    expect(subject.call).to eq(2)
  end
end
