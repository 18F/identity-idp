# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobHelpers::ServiceProviderMetadata do
  let(:test_class) do
    Class.new do
      include JobHelpers::ServiceProviderMetadata
    end
  end

  let(:helper) { test_class.new }

  describe '#get_service_provider_info' do
    let(:sp_data) do
      [
        {
          'issuer' => 'urn:gov:gsa:test1',
          'id' => 1,
          'friendly_name' => 'Test App 1',
          'agency_id' => 10,
          'active' => true,
          'agency_name' => 'General Services Administration',
          'agency_abbreviation' => 'GSA',
        },
        {
          'issuer' => 'urn:gov:gsa:test2',
          'id' => 2,
          'friendly_name' => 'Test App 2',
          'agency_id' => 20,
          'active' => false,
          'agency_name' => 'Department of Veterans Affairs',
          'agency_abbreviation' => 'VA',
        },
      ]
    end

    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_return(sp_data)
    end

    it 'returns service provider metadata for a valid issuer' do
      result = helper.get_service_provider_info('urn:gov:gsa:test1')

      expect(result).to eq(
        {
          id: 1,
          issuer_string: 'urn:gov:gsa:test1',
          friendly_name: 'Test App 1',
          active: true,
          agency_id: 10,
          agency_name: 'General Services Administration',
          agency_abbreviation: 'GSA',
        },
      )
    end

    it 'returns nil for an invalid issuer' do
      result = helper.get_service_provider_info('invalid:issuer')
      expect(result).to be_nil
    end

    it 'memoizes the mapping' do
      helper.get_service_provider_info('urn:gov:gsa:test1')
      helper.get_service_provider_info('urn:gov:gsa:test2')

      expect(ActiveRecord::Base.connection).to have_received(:execute).once
    end

    context 'when duplicate issuers exist' do
      let(:sp_data_with_dupes) do
        [
          {
            'issuer' => 'urn:gov:gsa:duplicate',
            'id' => 1,
            'friendly_name' => 'First App',
            'agency_id' => 10,
            'active' => true,
            'agency_name' => 'Agency One',
            'agency_abbreviation' => 'A1',
          },
          {
            'issuer' => 'urn:gov:gsa:duplicate',
            'id' => 2,
            'friendly_name' => 'Second App',
            'agency_id' => 20,
            'active' => false,
            'agency_name' => 'Agency Two',
            'agency_abbreviation' => 'A2',
          },
        ]
      end

      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(sp_data_with_dupes)
      end

      it 'keeps the first record and logs an error' do
        expect(Rails.logger).to receive(:error).with(/Duplicate issuer found/)

        result = helper.get_service_provider_info('urn:gov:gsa:duplicate')

        expect(result[:id]).to eq(1)
        expect(result[:friendly_name]).to eq('First App')
      end
    end

    context 'when database query fails' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
          StandardError, 'Database connection error'
        )
      end

      it 'logs an error and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch service provider metadata/)

        expect { helper.get_service_provider_info('any:issuer') }.to raise_error(
          StandardError, 'Database connection error'
        )
      end
    end

    context 'when no service providers exist' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return([])
      end

      it 'logs a warning and returns nil' do
        expect(Rails.logger).to receive(:warn).with(/No service providers found/)

        result = helper.get_service_provider_info('any:issuer')
        expect(result).to be_nil
      end
    end
  end

  describe '#get_service_provider_info_batch' do
    let(:sp_data) do
      [
        {
          'issuer' => 'urn:gov:gsa:test1',
          'id' => 1,
          'friendly_name' => 'Test App 1',
          'agency_id' => 10,
          'active' => true,
          'agency_name' => 'General Services Administration',
          'agency_abbreviation' => 'GSA',
        },
        {
          'issuer' => 'urn:gov:gsa:test2',
          'id' => 2,
          'friendly_name' => 'Test App 2',
          'agency_id' => 20,
          'active' => false,
          'agency_name' => 'Department of Veterans Affairs',
          'agency_abbreviation' => 'VA',
        },
      ]
    end

    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_return(sp_data)
    end

    it 'returns a hash mapping issuer strings to their metadata' do
      issuer_strings = ['urn:gov:gsa:test1', 'urn:gov:gsa:test2', 'invalid:issuer']
      result = helper.get_service_provider_info_batch(issuer_strings)

      expect(result.keys).to contain_exactly('urn:gov:gsa:test1', 'urn:gov:gsa:test2')
      expect(result['urn:gov:gsa:test1'][:id]).to eq(1)
      expect(result['urn:gov:gsa:test2'][:id]).to eq(2)
      expect(result).not_to have_key('invalid:issuer')
    end

    it 'returns an empty hash when no issuers match' do
      result = helper.get_service_provider_info_batch(['invalid:issuer1', 'invalid:issuer2'])
      expect(result).to eq({})
    end

    it 'uses the memoized mapping' do
      helper.get_service_provider_info_batch(['urn:gov:gsa:test1'])
      helper.get_service_provider_info_batch(['urn:gov:gsa:test2'])

      expect(ActiveRecord::Base.connection).to have_received(:execute).once
    end
  end

  describe 'SQL query' do
    it 'executes the expected SQL query' do
      expected_sql = <<~SQL
        SELECT 
          sp.issuer,
          sp.id,
          sp.friendly_name,
          sp.agency_id,
          sp.active,
          agencies.name as agency_name,
          agencies.abbreviation as agency_abbreviation
        FROM service_providers sp
        LEFT JOIN agencies ON sp.agency_id = agencies.id
        WHERE sp.issuer IS NOT NULL 
          AND TRIM(sp.issuer) <> ''
        ORDER BY sp.issuer;
      SQL

      allow(ActiveRecord::Base.connection).to receive(:execute).and_return([])

      helper.get_service_provider_info('any:issuer')

      expect(ActiveRecord::Base.connection).to have_received(:execute).with(expected_sql)
    end
  end

  describe 'data formatting' do
    let(:sp_data) do
      [
        {
          'issuer' => ' urn:gov:gsa:test1 ', # with whitespace
          'id' => 1,
          'friendly_name' => nil,
          'agency_id' => nil,
          'active' => true,
          'agency_name' => nil,
          'agency_abbreviation' => nil,
        },
        {
          'issuer' => 'urn:gov:gsa:test2',
          'id' => 2,
          'friendly_name' => 'Test App',
          'agency_id' => 20,
          'active' => false,
          'agency_name' => 'Department of Veterans Affairs',
          'agency_abbreviation' => 'VA',
        },
      ]
    end

    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_return(sp_data)
    end

    it 'handles nil values appropriately' do
      result = helper.get_service_provider_info(' urn:gov:gsa:test1 ')

      expect(result).to eq(
        {
          id: 1,
          issuer_string: ' urn:gov:gsa:test1 ',
          friendly_name: nil,
          active: true,
          agency_id: nil,
          agency_name: nil,
          agency_abbreviation: nil,
        },
      )
    end

    it 'preserves all data types correctly' do
      result = helper.get_service_provider_info('urn:gov:gsa:test2')

      expect(result[:id]).to be_a(Integer)
      expect(result[:issuer_string]).to be_a(String)
      expect(result[:active]).to be(false)
      expect(result[:agency_id]).to be_a(Integer)
    end
  end
end
