require 'rails_helper'

describe PivCacService do
  describe '#decode_token' do
    context 'when configured for local development' do
      before(:each) do
        allow(FeatureManagement).to receive(:development_and_piv_cac_entry_enabled?) { true }
      end

      it 'raises an error if no token provided' do
        expect {
          PivCacService.decode_token
        }.to raise_error ArgumentError
      end

      it 'returns the test data' do
        token = 'TEST:{"uuid":"hijackedUUID","dn":"hijackedDN"}'
        expect(PivCacService.decode_token(token)).to eq({
          'uuid' => 'hijackedUUID',
          'dn' => 'hijackedDN'
        })
      end
    end

    context 'with piv/cac service disabled' do
      before(:each) do
        allow(Figaro.env).to receive(:identity_pki_disabled) { 'true' }
      end

      it 'returns an error' do
        expect(PivCacService.decode_token('foo')).to eq({ 'error' => 'service.disabled' })
      end
    end

    context 'when communicating with piv/cac service' do
      before(:each) do
        allow(FeatureManagement).to receive(:development_and_piv_cac_entry_enabled?) { false }
      end

      it 'raises an error if no token provided' do
        expect {
          PivCacService.decode_token
        }.to raise_error ArgumentError
      end

      describe 'when configured with a user-facing endpoint' do
        before(:each) do
          allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
          allow(Figaro.env).to receive(:piv_cac_service_url) { 'http://localhost:1234' }
        end

        it { expect(PivCacService.piv_cac_service_link).to eq 'http://localhost:1234' }
      end

      describe 'when configured to contact remote service' do
        before(:each) do
          allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
          allow(Figaro.env).to receive(:piv_cac_verify_token_url) { 'http://localhost:8443/' }
        end

        let!(:request) do
          stub_request(:post, 'localhost:8443').
            with(body: 'token=foo').
            to_return(
              status: [200, 'Ok'],
              body: '{"dn":"dn","uuid":"uuid"}'
            )
        end

        it 'sends the token to the target service' do
          PivCacService.decode_token('foo')
          expect(request).to have_been_requested.once
        end

        it 'returns the decoded JSON from the target service' do
          expect(PivCacService.decode_token('foo')).to eq({
            'dn' => 'dn',
            'uuid' => 'uuid'
          })
        end

        describe 'with test data' do
          it 'returns an error' do
            token = 'TEST:{"uuid":"hijackedUUID","dn":"hijackedDN"}'
            expect(PivCacService.decode_token(token)).to eq({
              'error' => 'token.bad'
            })
          end
        end
      end

      describe 'with bad json' do
        before(:each) do
          allow(Figaro.env).to receive(:piv_cac_enabled) { 'true' }
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
          allow(Figaro.env).to receive(:piv_cac_verify_token_url) { 'http://localhost:8443/' }
        end

        let!(:request) do
          stub_request(:post, 'localhost:8443').
            with(body: 'token=foo').
            to_return(
              status: [200, 'Ok'],
              body: 'bad-json'
            )
        end

        it 'returns an error' do
          token = 'foo'
          expect(PivCacService.decode_token(token)).to eq({
            'error' => 'token.bad'
          })
        end
      end
    end
  end
end
