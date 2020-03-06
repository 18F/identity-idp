require 'rails_helper'

describe Db::Identity::SpActiveUserCounts do
  subject { described_class }

  let(:fiscal_start_date) { 1.year.ago.strftime('%m-%d-%Y') }

  it 'is empty' do
    expect(subject.call(fiscal_start_date).ntuples).to eq(0)
  end
end
