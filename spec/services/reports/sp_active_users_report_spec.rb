require 'rails_helper'

describe Reports::SpActiveUsersReport do
  subject { described_class.new }

  it 'is empty' do
    expect(subject.call).to eq('[]')
  end
end
