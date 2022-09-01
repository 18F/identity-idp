require 'rails_helper'

describe Proofing::LexisNexis::Ddp::ResponseRedacter do

  let(:json) { 
    Proofing::LexisNexis::Ddp::ResponseRedacter.
      redact(sample_hash)
  }

  describe 'self.redact' do
    context 'hash with unknown keys' do
      let(:sample_hash) {
        {
          'unknown_key' => 'dangerous data',
          'first_name' => 'unsafe first name',
          'ssn_hash' => 'unsafe ssn hash',
        }
      }
      it 'redacts unknown keys' do
        expect(json.values).to eq(['[redacted]']*3)
      end
      it 'keeps redacted keys' do
        expect(json.keys.length).to eq(3)
      end
    end

    context 'preserves known keys' do
      let(:sample_hash) {
        {
          'review_status' => 'safe value',
          'summary_risk_score' => 'safe value',
          'fraudpoint.score' => 'safe value'
        }
      }
      it 'redacts unknown keys' do
        expect(json.values).to eq(['safe value']*3)
      end
    end

    context 'nil hash argument' do
      let(:sample_hash) {
        nil
      }
      it 'produces an error about an empty body' do
        expect(json[:error]).to eq('TMx response body was empty')
      end
    end

    context 'mismatched data type argument' do
      let(:sample_hash) {
        Array.new
      }
      it 'produces an error about malformed body' do
        expect(json[:error]).to eq('TMx response body was malformed')
      end
    end

    context 'empty hash agrument' do
      let(:sample_hash) {
        Hash.new
      }
      it 'passes the empty hash onward' do
        expect(json).to eq(Hash.new)
      end
    end

  end

end
