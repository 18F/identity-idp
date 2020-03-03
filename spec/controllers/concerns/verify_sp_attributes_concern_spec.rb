require 'rails_helper'

RSpec.describe VerifySPAttributesConcern do
  controller ApplicationController do
    # ApplicationController already includes VerifySPAttributesConcern
  end

  describe '#consent_has_expired?' do
    let(:sp_session_identity) { build(:identity) }

    before do
      allow(controller).to receive(:sp_session_identity).and_return(sp_session_identity)
    end

    subject(:consent_has_expired?) { controller.consent_has_expired? }

    context 'when there is no last_consented_at' do
      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end

    context 'when last_consented_at within one year' do
      let(:sp_session_identity) { build(:identity, last_consented_at: 5.days.ago) }

      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when the last_consented_at is older than a year ago' do
      let(:sp_session_identity) { build(:identity, last_consented_at: 2.years.ago) }

      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end

    context 'when last_consented_at is nil but created_at is within a year' do
      let(:sp_session_identity) do
        build(:identity, last_consented_at: nil, created_at: 4.days.ago)
      end

      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when last_consented_at is nil and created_at is older than a year' do
      let(:sp_session_identity) do
        build(:identity, last_consented_at: nil, created_at: 4.years.ago)
      end

      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end
  end
end
