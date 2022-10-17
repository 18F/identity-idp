require 'rails_helper'

RSpec.describe InheritedProofingConcern do
  subject do
    Class.new do
      include InheritedProofingConcern
    end.new
  end

  before do
    allow(IdentityConfig.store).to receive(:inherited_proofing_enabled).and_return(true)
    allow(subject).to receive(:va_inherited_proofing_auth_code).and_return auth_code
  end

  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }
  let(:payload_hash) { Idv::InheritedProofing::Va::Mocks::Service::PAYLOAD_HASH }

  describe '#inherited_proofing_service_provider_id' do
    context 'when the service provider id can be identified' do
      it 'returns the service provider id as a Symbol' do
        expect(subject.inherited_proofing_service_provider_id).to eq \
          Idv::InheritedProofing::ServiceProviders::VA
      end
    end

    context 'when the service provider id cannot be identified' do
      before do
        allow(subject).to receive(:va_inherited_proofing_auth_code).and_return nil
      end

      it 'raises an error' do
        expected_error = 'Inherited proofing service id could not be identified'
        expect { subject.inherited_proofing_service_provider_id }.to raise_error expected_error
      end
    end
  end

  describe '#va_inherited_proofing?' do
    context 'when the va auth code is present' do
      it 'returns true' do
        expect(subject.va_inherited_proofing?).to eq true
      end
    end

    context 'when the va auth code is not present' do
      let(:auth_code) { nil }

      it 'returns false' do
        expect(subject.va_inherited_proofing?).to eq false
      end
    end
  end

  describe '#va_inherited_proofing_auth_code_params_key' do
    it 'returns the correct va auth code url query param key' do
      expect(subject.va_inherited_proofing_auth_code_params_key).to eq 'inherited_proofing_auth'
    end
  end

  describe '#inherited_proofing_service_class' do
    context 'when va inherited proofing is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:inherited_proofing_enabled).and_return(false)
      end

      it 'raises an error' do
        expect do
          subject.inherited_proofing_service_class
        end.to raise_error 'Inherited Proofing is not enabled'
      end
    end

    context 'when there is a va inherited proofing request' do
      context 'when va mock proofing is turned on' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(true)
        end

        it 'returns the correct service provider service class' do
          expect(subject.inherited_proofing_service_class).to \
            eq Idv::InheritedProofing::Va::Mocks::Service
        end
      end

      context 'when va mock proofing is turned off' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(false)
        end

        it 'returns the correct service provider service class' do
          expect(subject.inherited_proofing_service_class).to eq Idv::InheritedProofing::Va::Service
        end
      end
    end

    context 'when the inherited proofing request cannot be identified' do
      let(:auth_code) { nil }

      it 'raises an error' do
        expect do
          subject.inherited_proofing_service_class
        end.to raise_error 'Inherited proofing service class could not be identified'
      end
    end
  end

  describe '#inherited_proofing_service' do
    context 'when there is a va inherited proofing request' do
      context 'when va mock proofing is turned on' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(true)
        end

        it 'returns the correct service provider service class' do
          expect(subject.inherited_proofing_service).to \
            be_kind_of Idv::InheritedProofing::Va::Mocks::Service
        end
      end

      context 'when va mock proofing is turned off' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(false)
        end

        it 'returns the correct service provider service class' do
          expect(subject.inherited_proofing_service).to \
            be_kind_of Idv::InheritedProofing::Va::Service
        end
      end
    end
  end

  describe '#inherited_proofing_form' do
    context 'when there is a va inherited proofing request' do
      it 'returns the correct form' do
        expect(subject.inherited_proofing_form(payload_hash)).to \
          be_kind_of Idv::InheritedProofing::Va::Form
      end
    end

    context 'when the inherited proofing request cannot be identified' do
      let(:auth_code) { nil }

      it 'raises an error' do
        expect { subject.inherited_proofing_form(payload_hash) }.to \
          raise_error 'Inherited proofing form could not be identified'
      end
    end
  end

  describe '#inherited_proofing_service_provider_data' do
    context 'when there is a va inherited proofing request' do
      it 'returns the correct service provider-specific data' do
        expect(subject.inherited_proofing_service_provider_data).to \
          eq({ auth_code: auth_code })
      end
    end

    context 'when the inherited proofing request cannot be identified' do
      let(:auth_code) { nil }

      it 'returns an empty hash' do
        expect(subject.inherited_proofing_service_provider_data).to eq({})
      end
    end
  end
end
