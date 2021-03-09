require 'rails_helper'

describe AppArtifacts::Store do
  subject(:store) { AppArtifacts::Store.new }

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

        store.add_artifact('test_artifact', '/%<env>s/test_artifact')

        expect(store.test_artifact).to eq('test artifact')
        expect(store['test_artifact']).to eq('test artifact')
      end

      it 'raises an error if an artifact is missing' do
        expect(secrets_s3).to receive(:read_file).with(
          '/%<env>s/test_artifact',
        ).and_return(nil)

        expect do
          store.add_artifact('test_artifact', '/%<env>s/test_artifact')
        end.to raise_error(
          AppArtifacts::MissingArtifactError, 'missing artifact: /%<env>s/test_artifact'
        )
      end
    end

    context 'when running locally' do
      it 'reads the artifact from the example folder' do
        store.add_artifact('test_artifact', '/%<env>s/saml2021.crt')

        contents = File.read(Rails.root.join('config', 'artifacts.example', 'local', 'saml2021.crt'))
        expect(store.test_artifact).to eq(contents)
        expect(store['test_artifact']).to eq(contents)
      end

      it 'raises an error if an artifact is missing' do
        expect do
          store.add_artifact('test_artifact', '/%<env>s/dne.txt')
        end.to raise_error(
          AppArtifacts::MissingArtifactError, 'missing artifact: /%<env>s/dne.txt'
        )
      end
    end
  end

  describe '#method_missing' do
    it 'runs methods based on the stored artifact keys' do
      store.add_artifact('test_artifact', '/%<env>s/saml2021.crt')

      expect { store.test_artifact }.to_not raise_error
      expect { store.test_dne }.to raise_error(NoMethodError)
    end
  end
end
