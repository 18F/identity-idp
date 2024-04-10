require 'rails_helper'

RSpec.describe SignUp::PartnerAgencyExitController do
  before do
    allow(subject).to receive(:current_sp).and_return(current_sp)
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe '#show' do
    context 'when there is no SP' do
      let(:current_sp) { nil }

      it 'redirects to the account' do
        get 'show'

        expect(response).to redirect_to account_url
      end
    end
  end
end
