require 'rails_helper'
require 'data_requests/local'

RSpec.describe DataRequests::Local::WriteUserEvents do
  let(:requesting_issuer_uuid) { SecureRandom.uuid }

  describe '#call' do
    let(:user_report) do
      JSON.parse(
        File.read('spec/fixtures/data_request.json'), symbolize_names: true
      ).first
    end

    let(:io) { StringIO.new }
    let(:csv) { CSV.new(io) }

    subject(:writer) do
      described_class.new(
        user_report:,
        requesting_issuer_uuid:,
        csv:,
        include_header: true,
      )
    end

    it 'writes a file with event information' do
      writer.call

      parsed = CSV.parse(io.string, headers: true)
      expect(parsed.first['uuid']).to eq(requesting_issuer_uuid)
      expect(parsed.count).to eq(user_report[:user_events].length)
    end
  end
end
