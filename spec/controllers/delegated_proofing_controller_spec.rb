require 'rails_helper'

RSpec.describe DelegatedProofingController do
  describe '#create' do
    subject(:action) { post :create, params }
    let(:client_id) { 'urn:gov:gsa.openidconnect:delegated-proofing' }

    let(:params) do
      {
        user_id: SecureRandom.uuid,
        client_id: client_id,
        given_name_matches: true,
        family_name_matches: true,
        address_matches: true,
        birthdate_matches: true,
        social_security_number_matches: true,
        phone_matches: true,
      }
    end

    context 'without valid API credentials' do
      before { params[:client_id] = SecureRandom.uuid }

      it '401s' do
        expect(action).to be_unauthorized
      end
    end

    context 'with valid API credentials' do
      context 'with a valid request' do
        before do
          expect(controller.send(:delegated_proofing_form)).to receive(:submit)
            .and_return(FormResponse.new(success: true, errors: {}))
        end

        it 'is successful' do
          expect(action).to be_ok
        end
      end

      context 'with an invalid request' do
        before { params.delete(:user_id) }

        it '400s' do
          expect(action).to be_bad_request
        end
      end
    end
  end
end
