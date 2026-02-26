require 'rails_helper'

RSpec.describe Reports::BaseReport do
  subject(:report) { Reports::BaseReport.new }

  describe '#transaction_with_timeout' do
    let(:rails_env) { ActiveSupport::StringInquirer.new('production') }
    let(:report_timeout) { 999 }

    before do
      allow(IdentityConfig.store).to receive(:report_timeout).and_return(report_timeout)
    end

    it 'sets the statement_timeout inside a transaction' do
      result = report.send(:transaction_with_timeout, rails_env) do
        ActiveRecord::Base.connection.execute('SHOW statement_timeout')
      end

      expect(result.first['statement_timeout']).to eq("#{report_timeout}ms")
    end
  end
end
