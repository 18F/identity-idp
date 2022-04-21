require 'rails_helper'

RSpec.describe PsqlStatsJob, type: :job do
  describe '#perform' do
    it 'returns true' do
      result = PsqlStatsJob.new.perform(Time.zone.now)

      expect(result).to eq true
    end

    it 'logs psql table bloat metrics' do
      expect(IdentityJobLogSubscriber.reports_logger).to receive(:info) do |str|
        msg = JSON.parse(str, symbolize_names: true)
        expect(msg[:name]).to eq('psql_bloat_statistics')
        expect(msg[:table_data][:users][:tblname]).to eq('users')
      end

      PsqlStatsJob.new.perform(Time.zone.now)
    end
  end
end
