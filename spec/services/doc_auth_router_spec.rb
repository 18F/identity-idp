require 'rails_helper'

RSpec.describe DocAuthRouter do
  describe '.client' do
    before do
      allow(Figaro.env).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
      allow(Figaro.env).to receive(:acuant_simulator).and_return(acuant_simulator)
    end

    context 'legacy mock configuration' do
      let(:doc_auth_vendor) { '' }
      let(:acuant_simulator) { 'true' }

      it 'is the mock client' do
        expect(DocAuthRouter.client).to be_a(IdentityDocAuth::Mock::DocAuthMockClient)
      end
    end

    context 'for acuant' do
      let(:doc_auth_vendor) { 'acuant' }
      let(:acuant_simulator) { '' }

      it 'is the acuant client' do
        expect(DocAuthRouter.client).to be_a(IdentityDocAuth::Acuant::AcuantClient)
      end
    end

    context 'for lexisnexis' do
      let(:doc_auth_vendor) { 'lexisnexis' }
      let(:acuant_simulator) { '' }

      it 'is the lexisnexis client' do
        expect(DocAuthRouter.client).to be_a(IdentityDocAuth::LexisNexis::LexisNexisClient)
      end
    end

    context 'other config' do
      let(:doc_auth_vendor) { 'unknown' }
      let(:acuant_simulator) { '' }

      it 'errors' do
        expect { DocAuthRouter.client }.to raise_error(RuntimeError)
      end
    end
  end
end
