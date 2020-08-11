require 'rails_helper'

describe Reports::IaaBillingReport do
  subject { described_class.new }

  it 'is empty' do
    expect(subject.call).to be_present
  end
end
