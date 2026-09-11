require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Responses::PhoneRiskResponse do
  let(:phonerisk_low) { true }
  let(:name_phone_high) { true }
  let(:correlation_reason_codes) { ['I123', 'R567', 'R890'] }
  let(:phone_risk_reason_codes) { ['I123', 'R567'] }
  let(:name_verification_error_reason_codes) { ['R666', 'R777', 'R888'] }
  let(:response_body) do
    {
      'referenceId' => 'some-reference-id',
      'namePhoneCorrelation' => {
        'reasonCodes' => correlation_reason_codes,
        'score' => name_phone_high ? 0.99 : 0.01,
      },
      'phoneRisk' => {
        'reasonCodes' => phone_risk_reason_codes,
        'score' => phonerisk_low ? 0.01 : 0.99,
        'signals' => {
          'phone' => {},
        },
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

  before do
    allow(IdentityConfig.store).to receive(
      :idv_phone_verification_dual_vendor_check_socure_reason_codes,
    ).and_return(name_verification_error_reason_codes)
  end

  subject do
    described_class.new(http_response)
  end

  describe '#successful?' do
    it 'returns true' do
      expect(subject.successful?).to eq(true)
    end

    context 'phonerisk is above threshold' do
      let(:phonerisk_low) { false }
      it 'returns false' do
        expect(subject.successful?).to eq(false)
      end
    end

    context 'name phone correlation is below threshold' do
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
    let(:result) { subject.to_h }

    it 'returns the correct reason codes' do
      expect(result.dig(:phonerisk, :reason_codes).keys).to eq(phone_risk_reason_codes)
      expect(result.dig(:phonerisk, :score)).to eq(0.01)
      expect(
        result.dig(
          :name_phone_correlation,
          :reason_codes,
        ).keys,
      ).to eq(correlation_reason_codes)
      expect(result.dig(:name_phone_correlation, :score)).to eq(0.99)
    end

    it 'exposes the success and autofail signals' do
      expect(result[:name_correlation_successful]).to eq(true)
      expect(result[:phonerisk_successful]).to eq(true)
      expect(result[:autofail_reason_codes]).to eq([])
    end

    context 'phonerisk is above threshold' do
      let(:phonerisk_low) { false }

      it 'reports phonerisk as unsuccessful' do
        expect(result[:phonerisk_successful]).to eq(false)
      end
    end

    context 'name phone correlation is below threshold' do
      let(:name_phone_high) { false }

      it 'reports name correlation as unsuccessful' do
        expect(result[:name_correlation_successful]).to eq(false)
      end
    end

    context 'when an autofail reason code is present' do
      let(:autofail_reason_code) { 'R999' }
      let(:phone_risk_reason_codes) { ['I123', autofail_reason_code] }

      before do
        allow(IdentityConfig.store).to receive(
          :idv_socure_phonerisk_auto_failure_reason_codes,
        ).and_return([autofail_reason_code])
      end

      it 'includes the matched autofail reason codes' do
        expect(result[:autofail_reason_codes]).to eq([autofail_reason_code])
      end

      context 'when the autofail code is in the name phone correlation section' do
        let(:phone_risk_reason_codes) { ['I123'] }
        let(:correlation_reason_codes) { ['I123', autofail_reason_code] }

        it 'includes the matched autofail reason codes' do
          expect(result[:autofail_reason_codes]).to eq([autofail_reason_code])
        end
      end
    end

    context 'when a section is present but is missing reason codes' do
      let(:response_body) do
        {
          'referenceId' => 'some-reference-id',
          'namePhoneCorrelation' => { 'score' => 0.99 },
          'phoneRisk' => { 'score' => 0.01, 'signals' => { 'phone' => {} } },
          'customerProfile' => { 'customerUserId' => 'somebody' },
        }
      end

      it 'treats the missing reason codes as empty without raising' do
        expect(result.dig(:phonerisk, :reason_codes)).to eq({})
        expect(result.dig(:name_phone_correlation, :reason_codes)).to eq({})
        expect(result[:autofail_reason_codes]).to eq([])
      end
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

    context 'no name_phone_correlation section on response' do
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

  describe '#dual_vendor_check_eligible?' do
    let(:phone_risk_reason_codes) { ['I123', 'I801'] }
    let(:correlation_reason_codes) { ['I123', 'I800'] }

    context 'when phone risk reason codes contains a dual vendor eligible reason code' do
      let(:phone_risk_reason_codes) { ['I123', 'R666'] }

      context 'when no additional error reason codes are present' do
        it 'returns true' do
          expect(subject.dual_vendor_check_eligible?).to be(true)
        end
      end

      context 'when additional error reason codes are present' do
        let(:phone_risk_reason_codes) { ['I123', 'R666', 'R680'] }

        it 'returns false' do
          expect(subject.dual_vendor_check_eligible?).to be(false)
        end
      end
    end

    context 'when correlation reason codes contains a dual vendor eligible reason code' do
      let(:correlation_reason_codes) { ['I123', 'R888'] }

      context 'when no additional error reason codes are present' do
        it 'returns true' do
          expect(subject.dual_vendor_check_eligible?).to be(true)
        end
      end

      context 'when additional error reason codes are present' do
        let(:correlation_reason_codes) { ['I123', 'R777', 'R680'] }

        it 'returns false' do
          expect(subject.dual_vendor_check_eligible?).to be(false)
        end
      end
    end

    context 'when both reason codes do not contain dual vendor eligible reason codes' do
      it 'returns false' do
        expect(subject.dual_vendor_check_eligible?).to be(false)
      end
    end
  end
end
