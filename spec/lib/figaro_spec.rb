require 'rails_helper'

describe Figaro::Environment do
  let(:config) do
    {
      'test_key' => 'value',
      'production' => {
        'test_key' => 'overridden value',
      },
    }
  end

  let(:config_environment) { 'test' }

  before do
    stub_const('ENV', {})
  end

  describe '#initialize' do
    it 'warns and uses ENV when key is set in ENV and file config' do
      stub_const('ENV', 'test_key' => 'overridden value')
      expect do
        environment = described_class.new(config, config_environment)
        expect(environment.test_key).to eq 'overridden value'
      end.to output(
        /test_key is being loaded from ENV/,
      ).to_stderr
    end

    it 'overrides from specified environment key' do
      environment = described_class.new(config, 'production')

      expect(environment.test_key).to eq 'overridden value'
    end

    it 'sets ENV' do
      described_class.new(config, config_environment)

      expect(ENV['test_key']).to eq 'value'
    end
  end

  describe '#method_missing' do
    it 'reads from configuration' do
      environment = described_class.new(config, config_environment)

      expect(environment.test_key).to eq config['test_key']
    end
  end

  describe '#require_keys' do
    it 'does not raise an error if required keys are set' do
      environment = described_class.new(config, config_environment)

      expect(environment.require_keys(['test_key'])).to eq true
    end

    it 'raises an error if required key is not set' do
      environment = described_class.new(config, config_environment)

      expect { environment.require_keys(['unset_key']) }.to raise_error(
        RuntimeError,
        'unset_key is missing',
      )
    end
  end
end
