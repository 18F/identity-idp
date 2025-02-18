require 'rails_helper'

RSpec.describe Api::Attempts::EventsController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }

  before do
    allow(IdentityConfig.store).to receive(:attempts_api_enabled).and_return(enabled)
  end

  describe '#poll' do
    let(:sp) { create(:service_provider) }
    let(:issuer) { sp.issuer }
    let(:payload) do
      {
        maxEvents: '1000',
        acks: [
          'acknowleded-jti-id-1',
          'acknowleded-jti-id-2',
        ],
      }
    end

    let(:private_key) { OpenSSL::PKey::RSA.new 2048 }
    let(:public_key) { private_key.public_key }

    let(:public_cert) do
      return nil if !issuer
      name = OpenSSL::X509::Name.parse('/CN=signing')

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 0
      cert.not_before = Time.zone.now
      cert.not_after = Time.zone.now + 3600

      cert.public_key = public_key
      cert.subject = name
      cert.issuer = name

      cert.sign private_key, 'SHA256'

      cert.to_pem
    end

    let(:token) do
      JWT.encode(
        Digest::SHA256.hexdigest(payload.to_json),
        private_key,
        'RS256',
      )
    end

    let(:auth_header) { "Bearer #{issuer} #{token}" }

    before do
      request.headers['Authorization'] = auth_header
      allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
        [{
          issuer: sp.issuer,
          key: public_cert,
        }],
      )
    end

    let(:action) { post :poll, params: payload }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }

      context 'with a valid authorization header' do
        it 'returns 405 method not allowed' do
          expect(action.status).to eq(405)
        end
      end

      context 'with an invalid authorization header' do
        context 'with no Authorization header' do
          let(:auth_header) { nil }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'when Authorization header is an empty string' do
          let(:auth_header) { '' }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'without a Bearer token Authorization header' do
          let(:auth_header) { "#{issuer} #{token}" }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'without a valid issuer' do
          context 'an unknown issuer' do
            let(:issuer) { 'random-issuer' }

            it 'returns a 401' do
              expect(action.status).to eq 401
            end
          end
        end

        context 'without a valid public key' do
          let(:public_cert) { 'not-a-cert' }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end

        context 'with a valid but not matching public key' do
          let(:public_key) { OpenSSL::PKey::RSA.new(2048).public_key }

          it 'returns a 401' do
            expect(action.status).to eq 401
          end
        end
      end
    end
  end

  describe 'status' do
    let(:action) { get :status }

    context 'when the Attempts API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Attempts API is enabled' do
      let(:enabled) { true }
      it 'returns a 200' do
        expect(action.status).to eq(200)
      end

      it 'returns the disabled status and reason' do
        body = JSON.parse(action.body, symbolize_names: true)
        expect(body[:status]).to eq('disabled')
        expect(body[:reason]).to eq('not_yet_implemented')
      end
    end
  end
end
