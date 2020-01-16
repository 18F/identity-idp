require 'rails_helper'

describe Reports::SpCostReport do
  subject { described_class.new }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end
end
