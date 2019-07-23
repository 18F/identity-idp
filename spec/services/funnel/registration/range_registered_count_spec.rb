require 'rails_helper'

describe Funnel::Registration::RangeSubmittedCount do
  subject { described_class }

  it 'returns 0 when there are no records' do
    start = "2019-01-01 00:00:00"
    finish = "2019-12-01 00:00:00"

    expect(subject.call(start, finish)).to eq(0)
  end
end
