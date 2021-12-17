require 'rails_helper'

describe DataRequests::WriteUserEvents do
  describe '#call' do
    it 'writes a file with event information' do
      user_report = JSON.parse(
        File.read('spec/fixtures/data_request.json'), symbolize_names: true
      ).first

      Dir.mktmpdir do |dir|
        described_class.new(user_report, dir).call
        events = File.read(File.join(dir, 'events.csv'))
        csv = CSV.parse(events, headers: true)
        expect(csv.count).to eq(user_report[:user_events].length)
      end
    end
  end
end
