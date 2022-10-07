require 'rails_helper'

describe Funnel::Registration::RangeRegisteredCount do
  let(:analytics) { FakeAnalytics.new }
  subject { described_class }

  let(:start) { '2019-01-01 00:00:00' }
  let(:finish) { '2019-12-31 23:59:50' }

  it 'returns 0 when there are no records' do
    expect(subject.call(start, finish)).to eq(0)
  end

  it 'returns 1 when the record is mid range' do
    register_user(2019, 6, 1)

    expect(subject.call(start, finish)).to eq(1)
  end

  it 'returns 1 when the record is in same month is upper range' do
    register_user(2019, 12, 30)

    expect(subject.call(start, finish)).to eq(1)
  end

  it 'returns 1 when the record is in same month is lower range' do
    register_user(2019, 1, 2)

    expect(subject.call(start, finish)).to eq(1)
  end

  it 'returns 0 when the record is lower than lower range' do
    register_user(2018, 12, 31)

    expect(subject.call(start, finish)).to eq(0)
  end

  it 'returns 0 when the record is higher than higher range' do
    register_user(2020, 1, 2)

    expect(subject.call(start, finish)).to eq(0)
  end

  it 'returns 2 when 2 records are in range' do
    register_user(2019, 1, 2)
    register_user(2019, 12, 30)

    expect(subject.call(start, finish)).to eq(2)
  end

  def register_user(year, month, day)
    travel_to Date.new(year, month, day) do
      user = create(:user)
      user_id = user.id
      Funnel::Registration::Create.call(user_id)
    end
  end
end
