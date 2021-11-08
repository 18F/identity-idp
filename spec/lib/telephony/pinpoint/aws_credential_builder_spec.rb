require 'rails_helper'

describe Telephony::Pinpoint::AwsCredentialBuilder do
  include_context 'telephony'

  subject(:credential_builder) { described_class.new(config) }

  let(:credential_role_session_name) { nil }
  let(:credential_role_arn) { nil }
  let(:credential_external_id) { nil }
  let(:access_key_id) { nil }
  let(:secret_access_key) { nil }
  let(:region) { 'us-west-2' }

  context 'with assumed roles in the config' do
    let(:credential_role_session_name) { 'arn:123' }
    let(:credential_role_arn) { 'identity-idp' }
    let(:credential_external_id) { 'asdf1234' }

    let(:config) do
      Telephony::PinpointSmsConfiguration.new(
        region: region,
        credential_role_session_name: 'arn:123',
        credential_role_arn: 'identity-idp',
        credential_external_id: 'asdf1234',
      )
    end

    it 'returns an assumed role credential' do
      sts_client = double(Aws::STS::Client)
      allow(Aws::STS::Client).to receive(:new).with(region: region).and_return(sts_client)
      expected_credential = instance_double(Aws::AssumeRoleCredentials)
      expect(Aws::AssumeRoleCredentials).to receive(:new).with(
        role_session_name: credential_role_session_name,
        role_arn: credential_role_arn,
        external_id: credential_external_id,
        client: sts_client,
      ).and_return(expected_credential)

      result = credential_builder.call

      expect(result).to eq(expected_credential)
    end

    it 'returns nil if STS raises a Seahorse::Client::NetworkingError' do
      expected_credential = instance_double(Aws::AssumeRoleCredentials)
      expect(Aws::STS::Client).to receive(:new).and_raise(
        Seahorse::Client::NetworkingError.new(Net::ReadTimeout.new),
      )
      expect(Telephony.config.logger).to receive(:warn)

      result = credential_builder.call
      expect(result).to eq(nil)
    end
  end

  context 'with aws credentials in the config' do
    let(:access_key_id) { 'fake-access-key-id' }
    let(:secret_access_key) { 'fake-secret-key-id' }

    let(:config) do
      Telephony::PinpointVoiceConfiguration.new(
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
      )
    end

    it 'returns a plain old credential object' do
      result = credential_builder.call

      expect(result).to be_a(Aws::Credentials)
      expect(result.access_key_id).to eq(access_key_id)
      expect(result.secret_access_key).to eq(secret_access_key)
    end
  end

  context 'with no credentials in the config' do
    let(:config) { Telephony::PinpointVoiceConfiguration.new(region: region) }

    it 'returns nil' do
      result = credential_builder.call

      expect(result).to eq(nil)
    end
  end
end
