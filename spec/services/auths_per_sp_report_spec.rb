require 'rails_helper'

describe AuthsPerSpReport do
  describe '#call' do
    let(:days_ago) { 30 }

    it 'prints the report with zero records when there are no identities' do
      rows = AuthsPerSpReport.call(days_ago)

      expect(rows.count).to eq(0)
    end
  end
end
