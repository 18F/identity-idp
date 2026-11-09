require 'rails_helper'

RSpec.describe StsConsentForm do
  let(:user) { create(:user) }
  let(:target_app) { 'urn:gov:gsa:openidconnect:sp:broker' }

  subject(:form) { described_class.new(user:, target_app:) }

  before do
    allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
  end

  describe '#submit' do
    context 'when consent is given' do
      let(:params) { { consent_given: 'consented' } }

      it 'returns a successful response' do
        result = form.submit(params)

        expect(result.success?).to eq(true)
      end

      it 'persists a UserConsentSts record for the user and target_app' do
        expect { form.submit(params) }.to change { UserConsentSts.count }.by(1)

        consent = UserConsentSts.last
        expect(consent.user).to eq(user)
        expect(consent.target_app).to eq(target_app)
      end

      it 'does not create a duplicate when consent already exists' do
        UserConsentSts.create!(user:, target_app:)

        expect { form.submit(params) }.not_to change { UserConsentSts.count }
      end

      it 'refreshes an expired consent so it becomes valid again' do
        consent = UserConsentSts.create!(user:, target_app:)
        consent.update!(created_at: 366.days.ago)

        expect(form.submit(params).success?).to eq(true)
        expect(consent.reload.unexpired?).to eq(true)
      end
    end

    context 'when consent is not given' do
      let(:params) { { consent_given: '' } }

      it 'returns an unsuccessful response with a required_checkbox error' do
        result = form.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:consent_given]).to be_present
      end

      it 'does not persist a UserConsentSts record' do
        expect { form.submit(params) }.not_to change { UserConsentSts.count }
      end
    end
  end
end
