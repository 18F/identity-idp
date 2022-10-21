require 'rails_helper'

RSpec.describe Idv::InheritedProofing::ServiceProviderServices do
  subject do
    Class.new do
      include Idv::InheritedProofing::ServiceProviderServices
    end.new
  end

  let(:service_provider) { :va }
  let(:service_provider_data) { { auth_code: auth_code } }
  let(:auth_code) { Idv::InheritedProofing::Va::Mocks::Service::VALID_AUTH_CODE }

  describe '#inherited_proofing_service_class_for' do
    context 'when va inherited proofing is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:inherited_proofing_enabled).and_return(false)
      end

      it 'raises an error' do
        expect do
          subject.inherited_proofing_service_class_for(service_provider)
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
          expect(subject.inherited_proofing_service_class_for(service_provider)).to \
            eq Idv::InheritedProofing::Va::Mocks::Service
        end
      end

      context 'when va mock proofing is turned off' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(false)
        end

        it 'returns the correct service provider service class' do
          expect(subject.inherited_proofing_service_class_for(service_provider)).to \
            eq Idv::InheritedProofing::Va::Service
        end
      end
    end

    context 'when the inherited proofing class cannot be identified' do
      let(:service_provider) { :unknown_service_provider }

      it 'raises an error' do
        expect do
          subject.inherited_proofing_service_class_for(service_provider)
        end.to raise_error 'Inherited proofing service class could not be identified'
      end
    end
  end

  describe '#inherited_proofing_service_for' do
    context 'when there is a va inherited proofing request' do
      context 'when va mock proofing is turned on' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(true)
        end

        it 'returns the correct service provider service class' do
          expect(
            subject.inherited_proofing_service_for(
              service_provider,
              service_provider_data: service_provider_data,
            ),
          ).to \
            be_kind_of Idv::InheritedProofing::Va::Mocks::Service
        end
      end

      context 'when va mock proofing is turned off' do
        before do
          allow(IdentityConfig.store).to \
            receive(:va_inherited_proofing_mock_enabled).and_return(false)
        end

        it 'returns the correct service provider service class' do
          expect(
            subject.inherited_proofing_service_for(
              service_provider,
              service_provider_data: service_provider_data,
            ),
          ).to \
            be_kind_of Idv::InheritedProofing::Va::Service
        end
      end
    end
  end
end
