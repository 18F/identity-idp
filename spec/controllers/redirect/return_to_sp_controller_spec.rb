require 'rails_helper'

RSpec.describe Redirect::ReturnToSpController do
  let(:current_sp) { build(:service_provider) }

  before do
    allow(subject).to receive(:current_sp).and_return(current_sp)
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#cancel' do
    it 'redirects to the partner agency exit path' do
      get 'cancel'

      expect(response).to redirect_to sign_up_partner_agency_exit_url
    end
  end

  describe '#failure_to_proof' do
    context 'when there is no SP' do
      let(:current_sp) { nil }

      it 'redirects to the account' do
        get 'failure_to_proof'

        expect(response).to redirect_to account_url
      end
    end

    context 'when there is an SP in the session' do
      it 'redirects to the SP' do
        current_sp.failure_to_proof_url = 'https://sp.gov/failure_to_proof'

        get 'failure_to_proof'

        expect(response).to redirect_to('https://sp.gov/failure_to_proof')
        expect(@analytics).to have_received(:track_event).with(
          'Return to SP: Failed to proof',
          hash_including(redirect_url: 'https://sp.gov/failure_to_proof'),
        )
      end
    end

    context 'with step or location parameters' do
      it 'logs with extra analytics properties' do
        get 'failure_to_proof', params: { step: 'first', location: 'bottom' }

        expect(@analytics).to have_received(:track_event).with(
          'Return to SP: Failed to proof',
          hash_including(
            redirect_url: a_kind_of(String),
            step: 'first',
            location: 'bottom',
          ),
        )
      end
    end
  end
end
