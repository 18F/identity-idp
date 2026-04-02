# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'an endpoint that requires authorization' do
  context 'with no Authorization header' do
    let(:auth_header) { nil }

    it 'returns a 401' do
      expect(action.status).to eq 401

      expect(@analytics).to have_logged_event(
        :idv_proofing_agent_request_failed,
        success: false,
        failure_type: :authorization,
      )
    end
  end

  context 'when Authorization header is an empty string' do
    let(:auth_header) { '' }

    it 'returns a 401' do
      expect(action.status).to eq 401

      expect(@analytics).to have_logged_event(
        :idv_proofing_agent_request_failed,
        success: false,
        failure_type: :authorization,
      )
    end
  end

  context 'without a Bearer token Authorization header' do
    let(:auth_header) { "#{issuer} #{token}" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :idv_proofing_agent_request_failed,
        success: false,
        failure_type: :authorization,
      )
    end
  end

  context 'without a valid issuer' do
    context 'an unknown issuer' do
      let(:issuer) { 'random-issuer' }

      it 'returns a 401' do
        expect(action.status).to eq 401
        expect(@analytics).to have_logged_event(
          :idv_proofing_agent_request_failed,
          issuer:,
          success: false,
          failure_type: :authorization,
        )
      end
    end
  end

  context 'without a valid token' do
    let(:auth_header) { "Bearer #{issuer}" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :idv_proofing_agent_request_failed,
        success: false,
        failure_type: :authorization,
      )
    end
  end

  context 'with a different token than they were issued' do
    let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

    it 'returns a 401' do
      expect(action.status).to eq 401
      expect(@analytics).to have_logged_event(
        :idv_proofing_agent_request_failed,
        issuer:,
        success: false,
        failure_type: :authorization,
      )
    end
  end
end

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }

  let(:headers) do
    {
      'X-Proofing-Location-ID' => 'loc-123',
      'X-Proofing-Agent-ID' => 'agent-456',
      'X-Correlation-ID' => 'req-789',
    }
  end

  let(:correlation_id) { headers['X-Correlation-ID'] }

  let(:token) { 'a-shared-secret' }
  let(:salt) { SecureRandom.hex(32) }
  let(:cost) { IdentityConfig.store.scrypt_cost }

  let(:hashed_token) do
    scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
    scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
    SCrypt::Password.new(scrypted).digest
  end

  let(:auth_header) { "Bearer #{issuer} #{token}" }

  let(:drivers_license_type) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }
  let(:state_id_type) { Idp::Constants::DocumentTypes::STATE_ID_CARD }
  let(:identification_card_type) { Idp::Constants::DocumentTypes::IDENTIFICATION_CARD }
  let(:passport_type) { Idp::Constants::DocumentTypes::PASSPORT }
  let(:passport_card_type) { Idp::Constants::DocumentTypes::PASSPORT_CARD }
  let(:first_name) { 'FirstName' }
  let(:last_name) { 'LastName' }
  let(:dob) { (Time.zone.today - 14.years).strftime('%Y-%m-%d') }
  let(:document_number) { '123' }
  let(:jurisdiction) { 'MD' }
  let(:address1) { '123 Main' }
  let(:zip_code) { '12345-6789' }
  let(:expiration_date) { (Time.zone.today + 1.day).strftime('%Y-%m-%d') }
  let(:issuing_country_code) { 'USA' }
  let(:mrz) { 'P<USATRAVELER<<HAPPY<<<<<<<<<<<<<<<<<<<1234567890USA8501019M2412317<<<<<<<<<<<4' }
  let(:valid_residential_address) do
    {
      address1: '456 Side St',
      address2: 'Apt 123',
      city: 'City',
      state: 'MD',
      zip_code: '12354',
    }
  end
  let(:malformed_residential_address) do
    address = valid_residential_address.dup
    address[:zip_code] = '1234'
    address
  end
  let(:valid_state_id) do
    {
      document_number:,
      jurisdiction:,
      expiration_date:,
      issue_date: '2025-01-01',
      address1:,
      address2: nil,
      city: 'City',
      state: jurisdiction,
      zip_code:,
    }
  end
  let(:valid_passport) do
    {
      expiration_date:,
      issue_date: '2025-01-01',
      issuing_country_code:,
      mrz:,
    }
  end

  let(:id_type) { 'library_card' }
  let(:residential_address) { nil }
  let(:state_id) { nil }
  let(:passport) { nil }
  let(:agent_params) do
    ActionController::Parameters.new(
      suspected_fraud: false,
      email: 'foo@bar.com',
      first_name:,
      last_name:,
      dob:,
      phone: '555-555-5555',
      ssn: '111223333',
      id_type:,
      residential_address:,
      state_id:,
      passport:,
    )
  end

  before do
    stub_analytics
    request.headers['Authorization'] = auth_header
    allow(IdentityConfig.store).to receive(:idv_proofing_agent_config).and_return(
      [{
        'issuer' => sp.issuer,
        'tokens' => [{ 'value' => hashed_token, 'salt' => salt, 'cost' => cost }],
      }],
    )
    allow(FeatureManagement).to receive(:idv_proofing_agent_enabled?).and_return(enabled)
    headers.each { |key, value| request.headers[key] = value }
  end

  describe '#search_user' do
    let(:email) { 'user@example.com' }
    let(:ssn) { '123-45-6789' }
    let(:action) { post :search_user, params: { email: email, ssn: ssn } }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'with a valid authorization header' do
        it 'returns 200' do
          expect(action.status).to eq(200)
        end

        it 'includes correlation_id in the response' do
          action
          expect(response.headers['X-Correlation-ID']).to be_present
        end

        it 'returns the X-Correlation-ID header as correlation_id' do
          action
          expect(response.headers['X-Correlation-ID']).to eq('req-789')
        end

        it 'returns correct profiles and found attributes' do
          user = create(:user, email: email)
          Profile.create!(
            user_id: user.id,
            ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
            idv_level: 3,
          )
          Profile.create!(
            user_id: create(:user, email: 'other@example.com').id,
            ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
            idv_level: 2,
          )
          Profile.create!(
            user_id: create(:user, email: 'other1@example.com').id,
            ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('987-65-4321')),
            idv_level: 2,
          )
          action
          body = JSON.parse(response.body)
          expect(body['request_id']).to be_present
          expect(body['email_account_found']).to eq(true)
          expect(body['ssn_profile_found']).to eq(true)
          expect(body['profiles'].length).to eq(2)
          expect(body['profiles']).to include(
            a_hash_including(
              'email_match' => true,
              'ssn_match' => true,
              'idv_level' => 'enhanced',
            ),
            a_hash_including(
              'email_match' => false,
              'ssn_match' => true,
              'idv_level' => 'enhanced',
            ),
          )
          expect(@analytics).to have_logged_event(
            :idv_proofing_agent_account_check_requested,
            user_id: user.id,
            response_body: a_hash_including(
              email_account_found: true,
              ssn_profile_found: true,
              request_id: body['request_id'],
            ),
            agent_id: 'agent-456',
            location_id: 'loc-123',
            request_id: 'req-789',
          )
        end
        it 'requires both email and ssn in the payload' do
          post :search_user, params: { email: email }
          expect(response.status).to eq(400)

          post :search_user, params: { ssn: ssn }
          expect(response.status).to eq(400)
        end

        context 'without X-Proofing-Location-ID header' do
          let(:headers) do
            { 'X-Proofing-Agent-ID' => 'agent-456', 'X-Correlation-ID' => 'req-789' }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :validation,
              issuer:,
              agent_id: 'agent-456',
              correlation_id: 'req-789',
            )
          end
        end

        context 'without X-Proofing-Agent-ID header' do
          let(:headers) do
            { 'X-Proofing-Location-ID' => 'loc-123', 'X-Correlation-ID' => 'req-789' }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :validation,
              issuer:,
              location_id: 'loc-123',
              correlation_id: 'req-789',
            )
          end
        end

        context 'without X-Correlation-ID header' do
          let(:headers) do
            { 'X-Proofing-Location-ID' => 'loc-123', 'X-Proofing-Agent-ID' => 'agent-456' }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :validation,
              issuer:,
              agent_id: 'agent-456',
              location_id: 'loc-123',
            )
          end
        end

        context 'without any required headers' do
          let(:headers) { {} }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :validation,
              issuer:,
            )
          end

          it 'lists missing headers in error' do
            action
            body = JSON.parse(response.body)
            expect(body['error']).to include('X-Proofing-Location-ID')
            expect(body['error']).to include('X-Proofing-Agent-ID')
            expect(body['error']).to include('X-Correlation-ID')
          end
        end
      end

      context 'with an invalid authorization header' do
        it_behaves_like 'an endpoint that requires authorization'
      end
    end
  end

  describe '#proof_user' do
    before do
      allow(controller).to receive(:params).and_return(agent_params)
    end
    let(:action) { post :proof_user }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'when the id_type is drivers_licence and with valid state_id data' do
        let(:id_type) { drivers_license_type }
        let(:state_id) { valid_state_id }

        context 'with a valid authorization header' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('req-789')
          end

          context 'without X-Proofing-Location-ID header' do
            let(:headers) do
              { 'X-Proofing-Agent-ID' => 'agent-456', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Proofing-Agent-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                location_id: 'loc-123',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Proofing-Agent-ID' => 'agent-456' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                location_id: 'loc-123',
              )
            end
          end

          context 'without any required headers' do
            let(:headers) { {} }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end
        end

        context 'with an invalid authorization header' do
          it_behaves_like 'an endpoint that requires authorization'
        end

        context 'when the state_id data is not provided' do
          let(:state_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)

            body = JSON.parse(response.body)
            expect(body['error']).to eq('Missing parameter state_id')
          end
        end

        context 'when state_id and invalid residential address are provided' do
          let(:residential_address) { malformed_residential_address }

          it 'returns 400' do
            expect(action.status).to eq(400)

            body = JSON.parse(response.body)
            expect(body['zipcode'][0]).to eq('Enter a 5 or 9 digit ZIP Code')
          end
        end

        context 'when both state_id and passport provided' do
          let(:id_type) { drivers_license_type }
          let(:state_id) { valid_state_id }
          let(:passport) { valid_passport }
          let(:residential_address) { valid_residential_address }

          it 'returns 400' do
            expect(action.status).to eq(400)

            body = JSON.parse(response.body)
            expect(body['base'][0]).to eq('cannot include both state_id and passport')
          end
        end
      end

      context 'when the id_type is state_id_card and with valid state_id data' do
        let(:id_type) { state_id_type }
        let(:state_id) { valid_state_id }

        context 'with a valid authorization header' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('req-789')
          end

          context 'without X-Proofing-Location-ID header' do
            let(:headers) do
              { 'X-Proofing-Agent-ID' => 'agent-456', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Proofing-Agent-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                location_id: 'loc-123',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Proofing-Agent-ID' => 'agent-456' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                location_id: 'loc-123',
              )
            end
          end

          context 'without any required headers' do
            let(:headers) { {} }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end
        end
      end

      context 'when the id_type is identification_card and with valid state_id data' do
        let(:id_type) { identification_card_type }
        let(:state_id) { valid_state_id }

        context 'with a valid authorization header' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('req-789')
          end

          context 'without X-Proofing-Location-ID header' do
            let(:headers) do
              { 'X-Proofing-Agent-ID' => 'agent-456', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Proofing-Agent-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Correlation-ID' => 'req-789' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                location_id: 'loc-123',
                correlation_id: 'req-789',
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:headers) do
              { 'X-Proofing-Location-ID' => 'loc-123', 'X-Proofing-Agent-ID' => 'agent-456' }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
                agent_id: 'agent-456',
                location_id: 'loc-123',
              )
            end
          end

          context 'without any required headers' do
            let(:headers) { {} }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :validation,
                issuer:,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }

            it 'returns 400' do
              expect(action.status).to eq(400)
            end
          end
        end
      end

      context 'when the id_type is passport and with valid passport data' do
        let(:id_type) { passport_type }
        let(:passport) { valid_passport }
        let(:residential_address) { valid_residential_address }

        context 'when valid passport data is received' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end
        end

        context 'when the mrz is missing' do
          let(:mrz) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the passport is expired' do
          let(:expiration_date) { '2026-01-01' }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the first_name is missing' do
          let(:first_name) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the last_name is missing' do
          let(:last_name) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the dob is missing' do
          let(:dob) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the dob does not meet our minimum age requirements' do
          let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the residential address is missing' do
          let(:residential_address) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
          end
        end

        context 'when the passport data is not provided' do
          let(:passport) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)

            body = JSON.parse(response.body)
            expect(body['error']).to eq('Missing parameter passport')
          end
        end

        context 'when the id_type is passport_card' do
          let(:id_type) { passport_card_type }

          it 'returns 400' do
            expect(action.status).to eq(400)

            body = JSON.parse(response.body)
            expect(body['id_type']).to eq('Invalid id_type: passport_card')
          end
        end
      end
    end
  end
end
