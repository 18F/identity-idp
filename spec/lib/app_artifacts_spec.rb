require 'rails_helper'

RSpec.describe AppArtifacts::Store do
  subject(:instance) { AppArtifacts::Store.new }

  describe '#add_artifact' do
    context 'when in a deployed environment' do
      let(:secrets_s3) { double(Identity::Hostdata::S3) }

      before do
        allow(Identity::Hostdata).to receive(:in_datacenter?).and_return(true)
        allow(Identity::Hostdata).to receive(:secrets_s3).and_return(secrets_s3)
      end

      it 'reads the artifact from the secrets S3 bucket' do
        expect(secrets_s3).to receive(:read_file).with(
          '/%<env>s/test_artifact',
        ).and_return('test artifact')

        store = instance.build do |store|
          store.add_artifact(:test_artifact, '/%<env>s/test_artifact')
        end

        expect(store.test_artifact).to eq('test artifact')
        expect(store['test_artifact']).to eq('test artifact')
      end

      it 'raises an error if an artifact is missing' do
        expect(secrets_s3).to receive(:read_file).with(
          '/%<env>s/test_artifact',
        ).and_return(nil)

        expect do
          instance.build do |store|
            store.add_artifact(:test_artifact, '/%<env>s/test_artifact')
          end
        end.to raise_error(
          AppArtifacts::MissingArtifactError, 'missing artifact: /%<env>s/test_artifact'
        )
      end
    end

    context 'when running locally' do
      it 'reads the artifact from the example folder' do
        store = instance.build do |store|
          store.add_artifact(:test_artifact, '/%<env>s/saml2022.crt')
        end

        file_path = Rails.root.join('config', 'artifacts.example', 'local', 'saml2022.crt')
        contents = File.read(file_path)
        expect(store.test_artifact).to eq(contents)
        expect(store['test_artifact']).to eq(contents)
      end

      it 'raises an error if an artifact is missing' do
        expect do
          instance.build do |store|
            store.add_artifact(:test_artifact, '/%<env>s/dne.txt')
          end
        end.to raise_error(
          AppArtifacts::MissingArtifactError, 'missing artifact: /%<env>s/dne.txt'
        )
      end
    end

    it 'allows a block to be used to transform values' do
      store = instance.build do |store|
        store.add_artifact(:test_artifact, '/%<env>s/saml2022.crt') do |cert|
          OpenSSL::X509::Certificate.new(cert)
        end
      end

      file_path = Rails.root.join('config', 'artifacts.example', 'local', 'saml2022.crt')
      contents = File.read(file_path)
      expect(store.test_artifact).to be_a(OpenSSL::X509::Certificate)
      expect(store.test_artifact.to_pem).to eq(contents)
    end
  end

  describe '#method_missing' do
    it 'runs methods based on the configd artifact keys' do
      store = instance.build do |store|
        store.add_artifact(:test_artifact, '/%<env>s/saml2022.crt')
      end

      expect { store.test_artifact }.to_not raise_error
      expect { store.test_dne }.to raise_error(NoMethodError)
    end
  end
end
