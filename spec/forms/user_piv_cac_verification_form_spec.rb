require 'rails_helper'

describe UserPivCacVerificationForm do
  let(:form) { described_class.new(user: user, token: token, nonce: nonce) }
  let(:user) { create(:user, :with_piv_or_cac) }
  let(:nonce) { 'once' }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid' do
      let(:token) { 'good-token' }
      let(:x509_dn_uuid) { 'some-random-uuid' }

      let(:token_response) do
        {
          'uuid' => x509_dn_uuid,
          'subject' => 'x509-subject',
          'nonce' => nonce
        }
      end

      context 'and a user has no piv/cac associated' do
        let(:user) { create(:user) }

        it 'returns FormResponse with success: false' do
          result = instance_double(FormResponse)

          expect(FormResponse).to receive(:new).
            with(success: false, errors: {}).and_return(result)
          expect(form.submit).to eq result
          expect(form.error_type).to eq 'user.no_piv_cac_associated'
        end
      end

      context 'and a user has a different piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'returns FormResponse with success: false' do
          result = instance_double(FormResponse)

          expect(FormResponse).to receive(:new).
            with(success: false, errors: {}).and_return(result)
          expect(form.submit).to eq result
          expect(form.error_type).to eq 'user.piv_cac_mismatch'
        end
      end

      context 'and the correct piv/cac is presented' do
        let(:user) { create(:user, :with_piv_or_cac) }
        let(:x509_dn_uuid) { user.x509_dn_uuid }

        it 'returns FormResponse with success: true' do
          result = instance_double(FormResponse)

          expect(FormResponse).to receive(:new).
            with(success: true, errors: {}).and_return(result)
          expect(form.submit).to eq result
        end

        context 'when nonce is bad' do
          before(:each) do
            form.nonce = form.nonce + 'X'
          end

          it 'returns FormResponse with success: false' do
            result = instance_double(FormResponse)

            expect(FormResponse).to receive(:new).
              with(success: false, errors: {}).and_return(result)
            expect(Event).to_not receive(:create)
            expect(form.submit).to eq result
            expect(form.error_type).to eq 'token.invalid'
          end
        end
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce }
      end

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}).and_return(result)
        expect(Event).to_not receive(:create)
        expect(form.submit).to eq result
        expect(form.error_type).to eq 'token.bad'
      end
    end

    context 'when token is missing' do
      let(:token) { }

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}).and_return(result)
        expect(Event).to_not receive(:create)
        expect(form.submit).to eq result
      end
    end
  end
end
