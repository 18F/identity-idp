require 'rails_helper'

describe PivCacService do
  include Rails.application.routes.url_helpers

  describe '#randomize_uri' do
    let(:result) { PivCacService.send(:randomize_uri, uri) }

    context 'when a static URL is configured' do
      let(:uri) { 'http://localhost:1234/' }

      it 'returns the URL unchanged' do
        expect(result).to eq uri
      end
    end

    context 'when a random URL is configured' do
      let(:uri) { 'http://{random}.example.com/' }

      it 'returns the URL with random bytes' do
        expect(result).to_not eq uri
        expect(result).to match(%r{http://[0-9a-f]+\.example\.com/$})
      end
    end
  end

  describe '#decode_token' do
    context 'when configured for local development' do
      before(:each) do
        allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?) { true }
      end

      it 'raises an error if no token provided' do
        expect do
          PivCacService.decode_token
        end.to raise_error ArgumentError
      end

      it 'returns the test data' do
        token = 'TEST:{"uuid":"hijackedUUID","subject":"hijackedDN"}'
        expect(PivCacService.decode_token(token)).to eq(
          'uuid' => 'hijackedUUID',
          'subject' => 'hijackedDN',
        )
      end
    end

    context 'with piv/cac service disabled' do
      before(:each) do
        allow(Figaro.env).to receive(:identity_pki_disabled) { 'true' }
      end

      it 'returns an error' do
        expect(PivCacService.decode_token('foo')).to eq('error' => 'service.disabled')
      end
    end

    context 'when communicating with piv/cac service' do
      context 'when in non-development mode' do
        before(:each) do
          allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?) { false }
        end

        it 'raises an error if no token provided' do
          expect do
            PivCacService.decode_token
          end.to raise_error ArgumentError
        end

        describe 'when configured with a user-facing endpoint' do
          before(:each) do
            allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
            allow(Figaro.env).to receive(:piv_cac_service_url) { base_url }
          end

          let(:nonce) { 'once' }
          let(:base_url) { 'http://localhost:1234/' }
          let(:url_with_nonce) { "#{base_url}?nonce=#{nonce}" }

          it do
            expect(PivCacService.piv_cac_service_link(nonce)).to eq url_with_nonce
          end
        end

        context 'when in development mode' do
          before(:each) do
            allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?) { true }
          end
          let(:nonce) { 'once' }

          it 'directs the user to a local page' do
            expect(PivCacService.piv_cac_service_link(nonce)).to eq test_piv_cac_entry_url
          end
        end
      end

      describe 'when configured to contact remote service' do
        before(:each) do
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
          allow(Figaro.env).to receive(:piv_cac_verify_token_url) { 'http://localhost:8443/' }
        end

        let!(:request) do
          stub_request(:post, 'localhost:8443').
            with(
              body: 'token=foo',
              headers: { 'Authentication' => /^hmac\s+:.+:.+$/ },
            ).
            to_return(
              status: [200, 'Ok'],
              body: '{"subject":"dn","uuid":"uuid"}',
            )
        end

        it 'sends the token to the target service' do
          PivCacService.decode_token('foo')
          expect(request).to have_been_requested.once
        end

        it 'returns the decoded JSON from the target service' do
          expect(PivCacService.decode_token('foo')).to eq(
            'subject' => 'dn',
            'uuid' => 'uuid',
          )
        end

        describe 'with test data' do
          it 'returns an error' do
            token = 'TEST:{"uuid":"hijackedUUID","subject":"hijackedDN"}'
            expect(PivCacService.decode_token(token)).to eq(
              'error' => 'token.bad',
            )
          end
        end
      end

      describe 'with bad json' do
        before(:each) do
          allow(Figaro.env).to receive(:identity_pki_disabled) { 'false' }
          allow(Figaro.env).to receive(:piv_cac_verify_token_url) { 'http://localhost:8443/' }
        end

        let!(:request) do
          stub_request(:post, 'localhost:8443').
            with(body: 'token=foo').
            to_return(
              status: [200, 'Ok'],
              body: 'bad-json',
            )
        end

        it 'returns an error' do
          token = 'foo'
          expect(PivCacService.decode_token(token)).to eq(
            'error' => 'token.bad',
          )
        end
      end
    end
  end
end
