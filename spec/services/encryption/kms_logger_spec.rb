require 'rails_helper'

describe Encryption::KmsLogger do
  describe '.log' do
    context 'with a context' do
      it 'logs the context' do
        log = {
          kms: {
            action: 'encrypt',
            encryption_context: { context: 'pii-encryption', user_uuid: '1234-abc' },
          },
        }.to_json

        expect(described_class.logger).to receive(:info).with(log)

        described_class.log(:encrypt, context: 'pii-encryption', user_uuid: '1234-abc')
      end
    end

    context 'without a context' do
      it 'logs that an encryption happened without a context' do
        log = {
          kms: {
            action: 'decrypt',
            encryption_context: nil,
          },
        }.to_json

        expect(described_class.logger).to receive(:info).with(log)

        described_class.log(:decrypt)
      end
    end
  end

  describe '.logger' do
    it 'is a logger that write to log/kms.log' do
      expect(described_class.logger).to be_a(Logger)
      expect(described_class.logger.instance_variable_get(:@logdev).filename).to eq('log/kms.log')
    end
  end
end
