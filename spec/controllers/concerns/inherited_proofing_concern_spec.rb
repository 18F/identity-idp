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

  describe '#inherited_proofing?' do
    context 'when inherited proofing proofing is not effect' do
      let(:auth_code) { nil }

      it 'returns false' do
        expect(subject.inherited_proofing?).to eq false
      end
    end

    context 'when inherited proofing proofing is effect' do
      it 'returns true' do
        expect(subject.inherited_proofing?).to eq true
      end
    end
  end

  describe '#inherited_proofing_service_provider' do
    context 'when a service provider cannot be identified' do
      before do
        allow(subject).to receive(:va_inherited_proofing_auth_code).and_return nil
      end

      it 'returns nil' do
        expect(subject.inherited_proofing_service_provider).to eq nil
      end
    end

    context 'when a service provider can be identified' do
      let(:va) { :va }

      it 'returns the service provider' do
        expect(subject.inherited_proofing_service_provider).to eq va
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
