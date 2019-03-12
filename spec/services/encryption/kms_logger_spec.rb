require 'rails_helper'

describe Encryption::KmsLogger do
  describe '.log' do
    context 'with a context' do
      it 'logs the context' do
        described_class.log(:encrypt, context: 'pii-encryption', user_uuid: '1234-abc')

        log_contents = File.read('log/kms.log').split("\n")
        log = log_contents.last

        expect(log).to include(
          {
            kms: {
              action: 'encrypt',
              encryption_context: { context: 'pii-encryption', user_uuid: '1234-abc' },
            },
          }.to_json,
        )
      end
    end

    context 'without a context' do
      it 'logs that an encryption happened without a context' do
        described_class.log(:decrypt)

        log_contents = File.read('log/kms.log').split("\n")
        log = log_contents.last

        expect(log).to include(
          {
            kms: {
              action: 'decrypt',
              encryption_context: nil,
            },
          }.to_json,
        )
      end
    end
  end
end
