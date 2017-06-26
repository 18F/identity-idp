require 'rails_helper'

RSpec.describe DelegatedProofingConcern do
  controller(ApplicationController) do
    include DelegatedProofingConcern
  end

  describe '#delegated_proofing_session?' do
    context 'without an SP' do
      it { expect(controller.delegated_proofing_session?).to eq(false) }
    end

    context 'with an SP in the session' do
      let(:issuer) { 'some_issuer' }

      before { controller.session[:sp] = { issuer: issuer } }

      context 'with an SP that does not support delegated proofing' do
        it { expect(controller.delegated_proofing_session?).to eq(false) }
      end

      context 'with an SP that supports delegated proofing' do
        let(:issuer) { 'urn:gov:gsa.openidconnect:delegated-proofing' }

        it { expect(controller.delegated_proofing_session?).to eq(true) }
      end
    end
  end
end
