require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Responses::PhoneRiskResponse do
  let(:phonerisk_low) { true }
  let(:name_phone_high) { true }
  let(:response_body) do
    {
      'referenceId' => 'some-reference-id',
      'namePhoneCorrelation' => {
        'reasonCodes' => [
          'I123',
          'R567',
          'R890',
        ],
        'score' => name_phone_high ? 0.99 : 0.01,
      },
      'phoneRisk' => {
        'reasonCodes' => [
          'I123',
          'R567',
        ],
        'score' => phonerisk_low ? 0.01 : 0.99,
      },
      'customerProfile' => {
        'customerUserId' => 'somebody',
      },
    }
  end

  let(:http_response) do
    instance_double(Faraday::Response).tap do |r|
      allow(r).to receive(:body).and_return(response_body)
    end
  end

  subject do
    described_class.new(http_response)
  end

  describe '#successful?' do
    it 'is successful' do
      expect(subject.successful?).to eq(true)
    end

    context 'phonerisk is high' do
      let(:phonerisk_low) { false }
      it 'is not successful' do
        expect(subject.successful?).to eq(false)
      end
    end

    context 'name phone correlation is low' do
      let(:name_phone_high) { false }
      it 'is not successful' do
        expect(subject.successful?).to eq(false)
      end
    end
  end
  describe '#reference_id' do
    it 'returns referenceId' do
      expect(subject.reference_id).to eql('some-reference-id')
    end
  end

  describe '#cusomer_user_id' do
    it 'returns referenceId' do
      expect(subject.customer_user_id).to eql('somebody')
    end
  end

  describe '#to_h' do
    it 'returns the correct reason codes' do
      to_h = subject.to_h

      expect(to_h.dig(:phonerisk, :reason_codes).keys).to eq(['I123', 'R567'])
      expect(to_h.dig(:phonerisk, :score)).to eq(0.01)
      expect(to_h.dig(:name_phone_correlation, :reason_codes).keys).to eq(['I123', 'R567', 'R890'])
      expect(to_h.dig(:name_phone_correlation, :score)).to eq(0.99)
    end

    context 'no phonerisk section on response' do
      let(:response_body) do
        {
          customerProfile: {
            customerUserId: 'somebody',
          },
          namePhoneCorrelation: {},
        }
      end

      it 'raises an error' do
        expect do
          subject.to_h
        end.to raise_error(RuntimeError)
      end
    end

    context 'no name_phone_correla section on response' do
      let(:response_body) do
        {
          customerProfile: {
            customerUserId: 'somebody',
          },
          phoneRisk: {},
        }
      end

      it 'raises an error' do
        expect do
          subject.to_h
        end.to raise_error(RuntimeError)
      end
    end
  end
end
