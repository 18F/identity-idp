require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::ResponseRedacter do
  subject { described_class }

  let(:json) do
    Proofing::LexisNexis::Ddp::ResponseRedacter
      .redact(sample_hash)
  end

  describe 'self.redact' do
    let(:response_json) do
      {
        'unknown_key' => 'unknown',
        'input_ip_region' => Faker::Address.city,
        'input_ip_geo' => 'US',
        'input_ip_organization' => Faker::TvShows::Seinfeld.business,
        'input_ip_isp' => Faker::Internet.domain_word,
        'account_email_domain' => Faker::Internet.domain_name,
        'emailage.emailriskscore.fraud_type' => 'frauding',
        'emailage.emailriskscore.emailage' => '10 years',
        'emailage.emailriskscore.email_creation_days' => '1000',
        'emailage.emailriskscore.lastflaggedon' => '2020-12-01',
        'emailage.emailriskscore.source_industry' => Faker::Job.field,
      }
    end
    let(:sample_hash) do
      {
        'unknown_key' => 'dangerous data',
        'first_name' => 'unsafe first name',
        'ssn_hash' => 'unsafe ssn hash',
        'review_status' => 'safe value',
        'summary_risk_score' => 'safe value',
      }
    end

    context 'hash with mixed known and unknown keys' do
      it 'removes unknown keys and allows known keys' do
        expect(json).to eq(
          'review_status' => 'safe value',
          'summary_risk_score' => 'safe value',
        )
      end
    end

    context 'when the hash contains allowed and unallowed keys' do
      it 'returns a hash with the allowed keys' do
        expect(subject.redact(response_json).keys).to contain_exactly(
          'account_email_domain',
          'emailage.emailriskscore.emailage',
          'emailage.emailriskscore.email_creation_days',
          'emailage.emailriskscore.fraud_type',
          'emailage.emailriskscore.lastflaggedon',
          'emailage.emailriskscore.source_industry',
          'input_ip_geo',
          'input_ip_isp',
          'input_ip_organization',
          'input_ip_region',
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

    context 'empty hash argument' do
      let(:sample_hash) do
        {}
      end
      it 'passes the empty hash onward' do
        expect(json).to eq({})
      end
    end
  end
end
