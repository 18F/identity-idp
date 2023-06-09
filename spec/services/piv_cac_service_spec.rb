require 'rails_helper'

RSpec.describe PivCacService do
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
        allow(IdentityConfig.store).to receive(:identity_pki_disabled) { true }
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
            allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
            allow(IdentityConfig.store).to receive(:piv_cac_service_url) { base_url }
          end

          let(:nonce) { 'once' }
          let(:base_url) { 'http://localhost:1234/' }
          let(:redirect_uri) { 'http://example.com/asdf' }
          let(:url_with_nonce) do
            "#{base_url}?nonce=#{nonce}&redirect_uri=#{CGI.escape(redirect_uri)}"
          end

          it do
            link = PivCacService.piv_cac_service_link(
              nonce: nonce,
              redirect_uri: redirect_uri,
            )
            expect(link).to eq url_with_nonce
          end
        end

        context 'when in development mode' do
          before(:each) do
            allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?) { true }
          end
          let(:nonce) { 'once' }
          let(:redirect_uri) { 'http://example.com/asdf' }

          it 'directs the user to a local page' do
            test_url = test_piv_cac_entry_url(nonce: nonce, redirect_uri: redirect_uri)
            link = PivCacService.piv_cac_service_link(
              nonce: nonce,
              redirect_uri: redirect_uri,
            )
            expect(test_url).to eq link
          end
        end

        context 'when given a non-String token' do
          it 'returns bad token error' do
            expect(PivCacService.decode_token(1)).to eq(
              'error' => 'token.bad',
            )
          end
        end
      end

      describe 'when configured to contact piv_cac service for local development' do
        before(:each) do
          allow(IdentityConfig.store).to receive(:identity_pki_local_dev) { true }
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
          allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url) do
            'http://localhost:8443/'
          end
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

      describe 'when configured to contact remote service' do
        before(:each) do
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
          allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url) do
            'http://localhost:8443/'
          end
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
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
          allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url) do
            'http://localhost:8443/'
          end
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

      describe 'with HTTP failure' do
        before(:each) do
          allow(IdentityConfig.store).to receive(:identity_pki_disabled) { false }
          allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url) do
            'http://localhost:8443/'
          end
        end

        let!(:request) do
          stub_request(:post, 'localhost:8443').
            to_raise(Faraday::ConnectionFailed)
        end

        it 'returns an error' do
          expect(PivCacService.decode_token('foo')).to eq(
            'error' => 'token.http_failure',
          )
        end
      end
    end
  end
end
