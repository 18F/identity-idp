require 'rails_helper'

RSpec.describe Agreements::Db::SpReturnLogScan do
  describe '.call' do
    let(:issuers) { %w[issuer1 issuer2 issuer3] }

    before do
      issuers.each do |issuer|
        create(
          :sp_return_log,
          issuer: issuer,
          requested_at: Time.zone.now,
          ial: 1,
        )
      end
    end

    it 'scans through the sp_return_logs table and yields the block for each record' do
      output = []
      described_class.call { |record| output << record.issuer }

      expect(output).to match_array(issuers)
    end
  end
end
