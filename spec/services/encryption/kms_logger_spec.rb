require 'rails_helper'

RSpec.describe Encryption::KmsLogger do
  describe '.log' do
    context 'with a context' do
      it 'logs the context' do
        log = {
          kms: {
            action: 'encrypt',
            encryption_context: { context: 'pii-encryption', user_uuid: '1234-abc' },
          },
          log_filename: Encryption::KmsLogger::LOG_FILENAME,
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
          log_filename: Encryption::KmsLogger::LOG_FILENAME,
        }.to_json

        expect(described_class.logger).to receive(:info).with(log)

        described_class.log(:decrypt)
      end
    end
  end

  describe '.logger' do
    it 'is a logger' do
      expect(described_class.logger).to be_a(Logger)
    end
  end
end
