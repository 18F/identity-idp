require 'rails_helper'

describe Reports::UspsReport do
  subject { described_class }

  it 'is empty' do
    expect(JSON.parse(subject.new.call)).to be_present
  end
end
