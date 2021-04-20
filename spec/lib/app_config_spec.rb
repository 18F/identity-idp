require 'rails_helper'

describe AppConfig::Environment do
  let(:config) do
    {
      test_key: 'value',
    }
  end

  before do
    stub_const('ENV', {})
  end

  describe '#initialize' do
    it 'warns and uses ENV when key is set in ENV and file config' do
      ENV['test_key'] = 'aaa'
      expect do
        environment = described_class.new(config)
        expect(environment.test_key).to eq 'aaa'
      end.to output(
        /test_key is being loaded from ENV/,
      ).to_stderr
    end

    it 'warns if config value is not a string' do
      integer_value_config = {
        'test_key' => 1,
      }

      expect do
        described_class.new(integer_value_config)
      end.to output(
        /test_key value must be String/,
      ).to_stderr
    end
  end

  describe '#method_missing' do
    it 'reads from configuration' do
      environment = described_class.new(config)

      expect(environment.test_key).to eq config[:test_key]
    end
  end

  describe '#require_keys' do
    it 'does not raise an error if required keys are set' do
      environment = described_class.new(config)

      expect(environment.require_keys(['test_key'])).to eq true
    end

    it 'raises an error if required key is not set' do
      environment = described_class.new(config)

      expect { environment.require_keys(['unset_key']) }.to raise_error(
        RuntimeError,
        'unset_key is missing',
      )
    end
  end
end
