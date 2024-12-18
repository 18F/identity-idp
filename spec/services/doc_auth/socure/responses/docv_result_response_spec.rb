require 'rails_helper'

RSpec.describe DocAuth::Socure::Responses::DocvResultResponse do
  subject(:response) do
    described_class.new(http_response:, biometric_comparison_required:)
  end

  let(:http_response) { double('fake faraday response') }
  let(:biometric_comparison_required) { false }
  let(:response_json) { SocureDocvFixtures.pass_json }

  before do
    allow(http_response).to receive(:body).and_return(response_json)
  end

  context 'happy path' do
    it 'success? is true' do
      expect(subject.success?).to eq(true)
    end

    it 'doc_type is supported' do
      expect(subject.doc_type_supported?).to eq(true)
    end
  end

  context 'with a Socure error' do
    let(:response_json) { SocureDocvFixtures.fail_json(['I808']) }

    it 'fails' do
      expect(subject.success?).to eq(false)
    end

    it 'adds the socure error to the errors' do
      expect(subject.errors.dig(:socure, :reason_codes)).to eq(['I808'])
    end
  end

  context 'when the PII is not satisfactory' do
    before do
      allow_any_instance_of(Idv::DocAuthFormResponse).to receive(:success?).and_return(false)
    end

    it 'fails' do
      expect(subject.success?).to eq(false)
    end

    it 'adds the pii error to the errors' do
      expect(subject.errors).to have_key(:validation_failed)
    end
  end
end
