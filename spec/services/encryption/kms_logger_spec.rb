require 'rails_helper'

RSpec.describe Encryption::KmsLogger do
  describe '.log' do
    let(:log_timestamp) { Time.utc(2025, 2, 28, 15, 30, 1) }

    context 'with a context' do
      it 'logs the context' do
        log = {
          kms: {
            timestamp: log_timestamp,
            action: 'encrypt',
            encryption_context: { context: 'pii-encryption', user_uuid: '1234-abc' },
            log_context: 'log_context',
            key_id: 'super-duper-aws-kms-key-id',
          },
          log_filename: Idp::Constants::KMS_LOG_FILENAME,
        }.to_json

        expect(described_class.logger).to receive(:info).with(log)

        described_class.log(
          action: :encrypt,
          context: { context: 'pii-encryption', user_uuid: '1234-abc' },
          log_context: 'log_context',
          key_id: 'super-duper-aws-kms-key-id',
          timestamp: log_timestamp,
        )
      end
    end

    context 'without a context' do
      it 'logs that an encryption happened without a context' do
        log = {
          kms: {
            timestamp: log_timestamp,
            action: 'decrypt',
            encryption_context: nil,
            log_context: nil,
            key_id: 'super-duper-aws-kms-key-id',
          },
          log_filename: Idp::Constants::KMS_LOG_FILENAME,
        }.to_json

        expect(described_class.logger).to receive(:info).with(log)

        described_class.log(
          action: :decrypt,
          timestamp: log_timestamp,
          key_id: 'super-duper-aws-kms-key-id',
        )
      end
    end
  end

  describe '.logger' do
    it 'is a logger' do
      expect(described_class.logger).to be_a(Logger)
    end
  end
end
