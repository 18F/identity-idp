# frozen_string_literal: true

require 'rails_helper'

MrzResponse = Struct.new(:body, :status, :success?)

RSpec.describe DocAuth::Dos::Requests::MrzRequest do
  let(:mrz) { '1234567890' }
  let(:request_id) { '1234567890' }
  let(:subject) do
    DocAuth::Dos::Requests::MrzRequest.new(request_id: request_id, mrz: mrz)
  end
  let(:mrz_result) { 'YES' }
  let(:mrz_response) do
    MrzResponse.new(body: { response: mrz_result }.to_json, status: 200, success?: true)
  end

  before do
    allow(subject).to receive(:send_http_request).and_return(mrz_response)
  end

  after do
    # Do nothing
  end

  context 'when the MRZ matches' do
    it 'succeeds' do
      expect(subject.fetch.success?).to be(true)
    end
  end

  context "when the MRZ doesn't match" do
    let(:mrz_result) { 'NO' }

    it 'fails' do
      expect(subject.fetch.success?).to be(false)
    end
  end

  context "when the response is neither 'YES' or 'NO'" do
    let(:mrz_result) { 'MAYBE' }

    it 'fails with a message' do
      expect(subject.fetch.success?).to be(false)
      expect(subject.fetch.errors).to include(message: "Unexpected response: #{mrz_result}")
    end
  end
end
