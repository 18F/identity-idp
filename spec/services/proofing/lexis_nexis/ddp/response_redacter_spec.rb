require 'rails_helper'

describe Proofing::LexisNexis::Ddp::ResponseRedacter do
  let(:json) do
    Proofing::LexisNexis::Ddp::ResponseRedacter.
      redact(sample_hash)
  end

  describe 'self.redact' do
    let(:sample_hash) do
      {
        'unknown_key' => 'dangerous data',
        'first_name' => 'unsafe first name',
        'ssn_hash' => 'unsafe ssn hash',
        'review_status' => 'safe value',
        'summary_risk_score' => 'safe value',
        'fraudpoint.score' => 'safe value',
      }
    end
    context 'hash with mixed known and unknown keys' do
      it 'redacts values of unknown keys and allows known keys' do
        expect(json).to eq(
          'unknown_key' => '[redacted]',
          'first_name' => '[redacted]',
          'ssn_hash' => '[redacted]',
          'review_status' => 'safe value',
          'summary_risk_score' => 'safe value',
          'fraudpoint.score' => 'safe value',
        )
      end
    end

    context 'nil hash argument' do
      let(:sample_hash) do
        nil
      end
      it 'produces an error about an empty body' do
        expect(json[:error]).to eq('TMx response body was empty')
      end
    end

    context 'mismatched data type argument' do
      let(:sample_hash) do
        []
      end
      it 'produces an error about malformed body' do
        expect(json[:error]).to eq('TMx response body was malformed')
      end
    end

    context 'empty hash agrument' do
      let(:sample_hash) do
        {}
      end
      it 'passes the empty hash onward' do
        expect(json).to eq({})
      end
    end
  end
end
