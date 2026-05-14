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
        proofing_agent: a_kind_of(Hash),
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
        proofing_agent: a_kind_of(Hash),
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
        proofing_agent: a_kind_of(Hash),
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
          success: false,
          failure_type: :authorization,
          proofing_agent: a_kind_of(Hash),
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
        proofing_agent: a_kind_of(Hash),
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
        proofing_agent: a_kind_of(Hash),
      )
    end
  end
end

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  include Rails.application.routes.url_helpers
  let(:enabled) { false }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:correlation_id) { 'correlation-789' }
  let(:location_id) { 'loc-123' }
  let(:agent_id) { 'agent-456' }

  let(:headers) do
    {
      'X-Correlation-ID' => correlation_id,
    }
  end
  let(:missing_headers_errors) do
    headers = 'X-Correlation-ID'
    {
      error: "Missing required headers: #{headers}",
    }
  end

  let(:proofing_agent_analytics_hash) do
    a_hash_including(correlation_id:, location_id:, agent_id:)
  end
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
  let(:expiration_date) { (Time.zone.today + 1.year).strftime('%Y-%m-%d') }
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

  let(:user) { create(:user) }
  let(:email) { user.email }
  let(:body_errors) { { foo: 'bar' } }
  let(:body_failure_event_attrs) do
    {
      success: false,
      issuer:,
      failure_type: :body_validation,
      proofing_agent: {
        agent_id: 'agent-456',
        correlation_id: 'correlation-789',
        location_id: 'loc-123',
      },
      errors: body_errors,
    }
  end

  let(:id_type) { 'library_card' }
  let(:residential_address) { nil }
  let(:state_id) { nil }
  let(:passport) { nil }
  let(:agent_params) do
    ActionController::Parameters.new(
      proofing_agent_id: agent_id,
      proofing_location_id: location_id,
      suspected_fraud: false,
      email:,
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
    stub_analytics(user:)
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
    let(:ssn) { '123-45-6789' }
    let(:action) do
      post :search_user, params: {
        proofing_agent_id: agent_id,
        proofing_location_id: location_id,
        email:,
        ssn:,
      }.compact
    end

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
          expect(response.headers['X-Correlation-ID']).to eq(correlation_id)
        end

        context 'when the email param does not match any users' do
          let(:user) { nil }
          let(:email) { 'nonexistent@example.com' }

          context 'when the ssn does not match any profiles' do
            it 'returns email_account_found as false and ssn_profile_found as false' do
              action
              body = JSON.parse(response.body)
              expect(body['email_account_found']).to eq(false)
              expect(body['ssn_profile_found']).to eq(false)
              expect(body['profiles']).to eq([])
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_account_check_requested,
                response_body: a_hash_including(
                  email_account_found: false,
                  ssn_profile_found: false,
                  profiles: [],
                ),
                proofing_agent: proofing_agent_analytics_hash,
                issuer:,
              )
            end
          end

          context 'when the ssn matches profiles' do
            it 'returns email_account_found as false and ssn_profile_found as true' do
              create(
                :profile,
                :active,
                user: create(:user, email: 'other@example.com'),
                idv_level: 2,
                ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              )
              action
              body = JSON.parse(response.body)
              expect(body['email_account_found']).to eq(false)
              expect(body['ssn_profile_found']).to eq(true)
              expect(body['profiles'].length).to eq(1)
              expect(body['profiles']).to include(
                a_hash_including(
                  'email_match' => false,
                  'ssn_match' => true,
                  'idv_level' => 'enhanced',
                ),
              )
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_account_check_requested,
                response_body: a_hash_including(
                  email_account_found: false,
                  ssn_profile_found: true,
                  profiles: include(
                    a_hash_including(
                      email_match: false,
                      ssn_match: true,
                      idv_level: 'enhanced',
                    ),
                  ),
                ),
                proofing_agent: proofing_agent_analytics_hash,
                issuer:,
              )
            end
          end
        end

        context 'when the user nor ssn have any profiles' do
          it 'returns correct profiles and found attributes' do
            create(
              :profile,
              :deactivated,
              user:,
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 3,
            )
            action
            body = JSON.parse(response.body)
            expect(body['email_account_found']).to eq(true)
            expect(body['ssn_profile_found']).to eq(false)
            expect(body['profiles'].length).to eq(0)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_account_check_requested,
              response_body: a_hash_including(
                email_account_found: true,
                ssn_profile_found: false,
                profiles: [],
              ),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
            )
          end
        end

        context 'when the email and ssn match same profiles' do
          it 'returns correct profiles and found attributes' do
            create(
              :profile,
              :active,
              user:,
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 3,
            )
            create(
              :profile,
              :deactivated,
              user:,
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('999-99-9999')),
              idv_level: 1,
            )
            create(
              :profile,
              :active,
              user: create(:user, email: 'other@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 2,
            )
            create(
              :profile,
              :deactivated,
              user: create(:user, email: 'another@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 2,
            )
            create(
              :profile,
              :active,
              user: create(:user, email: 'other1@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('987-65-4321')),
              idv_level: 2,
            )
            create(
              :profile,
              :active,
              user: create(:user, email: 'another1@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 1,
            )
            action
            body = JSON.parse(response.body)
            expect(body['email_account_found']).to eq(true)
            expect(body['ssn_profile_found']).to eq(true)
            expect(body['profiles'].length).to eq(3)
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
              a_hash_including(
                'email_match' => false,
                'ssn_match' => true,
                'idv_level' => 'basic',
              ),
            )
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_account_check_requested,
              response_body: a_hash_including(
                email_account_found: true,
                ssn_profile_found: true,
                profiles: include(
                  a_hash_including(
                    email_match: true,
                    ssn_match: true,
                    idv_level: 'enhanced',
                  ),
                  a_hash_including(
                    email_match: false,
                    ssn_match: true,
                    idv_level: 'enhanced',
                  ),
                  a_hash_including(
                    email_match: false,
                    ssn_match: true,
                    idv_level: 'basic',
                  ),
                ),
              ),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
            )
          end
        end

        context 'when the email and ssn match different profiles' do
          it 'returns correct profiles and found attributes' do
            create(
              :profile,
              :active,
              user:,
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('999-99-9999')),
              idv_level: 3,
            )
            create(
              :profile,
              :deactivated,
              user:,
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('999-99-9999')),
              idv_level: 1,
            )
            create(
              :profile,
              :active,
              user: create(:user, email: 'other@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 2,
            )
            create(
              :profile,
              :deactivated,
              user: create(:user, email: 'another@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
              idv_level: 2,
            )
            create(
              :profile,
              :active,
              user: create(:user, email: 'other1@example.com'),
              ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize('987-65-4321')),
              idv_level: 2,
            )
            action
            body = JSON.parse(response.body)
            expect(body['email_account_found']).to eq(true)
            expect(body['ssn_profile_found']).to eq(true)
            expect(body['profiles'].length).to eq(2)
            expect(body['profiles']).to include(
              a_hash_including(
                'email_match' => true,
                'ssn_match' => false,
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
              response_body: a_hash_including(
                email_account_found: true,
                ssn_profile_found: true,
                profiles: include(
                  a_hash_including(
                    email_match: true,
                    ssn_match: false,
                    idv_level: 'enhanced',
                  ),
                  a_hash_including(
                    email_match: false,
                    ssn_match: true,
                    idv_level: 'enhanced',
                  ),
                ),
              ),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
            )
          end
        end

        context 'requires both email and ssn in the payload' do
          context 'without ssn' do
            let(:ssn) { nil }
            it 'returns 400 if ssn is missing' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { ssn: ['Please fill in this field.',
                                'Enter a nine-digit Social Security number', 'cannot be blank'] },
              )
            end
          end

          context 'with invalid ssn' do
            let(:ssn) { 'invalid' }
            it 'returns 400 if ssn is invalid' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { ssn: ['Enter a nine-digit Social Security number'] },
              )
            end
          end

          context 'without email' do
            let(:user) { nil }
            let(:email) { nil }
            it 'returns 400 if email is missing' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { email: ['cannot be blank'] },
              )
            end
          end
        end

        context 'without proofing_locaton_id param' do
          let(:location_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :body_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: { proofing_location_id: ['cannot be blank'] },
            )
          end
        end

        context 'without proofing_agent_id param' do
          let(:agent_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :body_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: { proofing_agent_id: ['cannot be blank'] },
            )
          end
        end

        context 'without X-Correlation-ID header' do
          let(:correlation_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :header_validation,
              issuer:,
              proofing_agent: a_hash_including(
                agent_id: 'agent-456',
                location_id: 'loc-123',
                correlation_id: nil,
              ),
              errors: missing_headers_errors,
            )
          end
        end

        context 'without any required headers' do
          let(:correlation_id) { nil }
          let(:agent_id) { nil }
          let(:location_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :header_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: missing_headers_errors,
            )
          end

          it 'lists missing headers in error' do
            action
            body = JSON.parse(response.body)
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

        context 'when rate limit reached for the user' do
          before do
            RateLimiter.new(user:, rate_limit_type: :idv_resolution).increment_to_limited!
            RateLimiter.new(user:, rate_limit_type: :proof_ssn).increment_to_limited!
          end
          it 'returns 429 and logs events' do
            expect(action.status).to eq(429)
            expect(@analytics).to have_logged_event(
              'Rate Limit Reached',
              limiter_type: :idv_resolution,
              step_name: 'proof_user',
            )
            expect(@analytics).to have_logged_event(
              'Rate Limit Reached',
              limiter_type: :proof_ssn,
              step_name: 'proof_user',
            )
          end
        end

        context 'with a valid authorization header' do
          it 'returns 202 accepted' do
            expect(action.status).to eq(202)
            transaction_id = DocumentCaptureSession.last.uuid

            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(status: 'pending', transaction_id:),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
              remaining_attempts: a_kind_of(Integer),
            )
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('correlation-789')
          end

          context 'user account does not exist' do
            let(:user) { nil }
            let(:email) { 'nonexistent@example.com' }

            it 'returns 422 unprocessible_content' do
              expect(action.status).to eq(422)
            end

            it 'returns a failed response body' do
              action
              body = JSON.parse(response.body)

              expect(body['status']).to eq('failed')
              expect(body['reason']).to eq('email_not_found')

              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_received,
                response_body: a_hash_including(status: 'failed', reason: 'email_not_found'),
                proofing_agent: proofing_agent_analytics_hash,
                issuer:,
              )
            end
          end

          context 'user already has an enhanced profile' do
            let(:ssn) { '111-22-3333' }
            before do
              Profile.create!(
                user_id: user.id,
                ssn_signature: Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn)),
                idv_level: 3,
                active: true,
              )
            end

            it 'returns 200' do
              expect(action.status).to eq(200)
            end

            it 'returns a failed already proofed response body' do
              action
              body = JSON.parse(response.body)
              expect(body['status']).to eq('failed')
              expect(body['reason']).to eq('already_proofed_enhanced')

              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_received,
                response_body: a_hash_including(
                  status: 'failed',
                  reason: 'already_proofed_enhanced',
                ),
                proofing_agent: proofing_agent_analytics_hash,
                issuer:,
              )
            end
          end

          context 'without proofing_location_id param' do
            let(:location_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_location_id: ['cannot be blank'] },
              )
            end
          end

          context 'without proofing_agent_id param' do
            let(:agent_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_agent_id: ['cannot be blank'] },
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:correlation_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: missing_headers_errors,
              )
            end
          end

          context 'without any required headers' do
            let(:correlation_id) { nil }
            let(:agent_id) { nil }
            let(:location_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: missing_headers_errors,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }
            let(:body_errors) { { first_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['first_name'][0]).to eq(body_errors[:first_name][0])
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }
            let(:body_errors) { { last_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['last_name'][0]).to eq(body_errors[:last_name][0])
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }
            let(:body_errors) { { dob: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob'][0]).to eq(body_errors[:dob][0])
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }
            let(:body_errors) { { dob_min_age: ['age does not meet minimum requirements'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob_min_age'][0]).to eq(body_errors[:dob_min_age][0])
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }
            let(:body_errors) { { address1: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['address1'][0]).to eq(body_errors[:address1][0])
            end
          end

          context 'when the zip_code is missing' do
            let(:zip_code) { nil }
            let(:body_errors) { { zip_code: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['zip_code'][0]).to eq(body_errors[:zip_code][0])
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }
            let(:body_errors) { { zip_code: ['is invalid'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['zip_code'][0]).to eq(body_errors[:zip_code][0])
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }
            let(:body_errors) do
              { jurisdiction: ['cannot be blank', 'is not a valid state code'],
                state: ['cannot be blank', 'is not a valid state code'] }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['jurisdiction'][0]).to eq(body_errors[:jurisdiction][0])
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }
            let(:body_errors) { { document_number: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['document_number'][0]).to eq(body_errors[:document_number][0])
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }
            let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
            end
          end

          context 'when the state_id is near expiration (2 days away)' do
            let(:expiration_date) { (Time.zone.today + 2.days).strftime('%Y-%m-%d') }
            let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
            end
          end

          context 'when the state_id is near expiration (3 days away)' do
            let(:expiration_date) { (Time.zone.today + 3.days).strftime('%Y-%m-%d') }
            let(:body_errors) { {} }

            it 'returns 202' do
              expect(action.status).to eq(202)
              expect(@analytics).not_to have_logged_event(:idv_proofing_agent_request_failed)
            end
          end
        end

        context 'with an invalid authorization header' do
          it_behaves_like 'an endpoint that requires authorization'
        end

        context 'when the state_id data is not provided' do
          let(:state_id) { nil }
          let(:body_errors) do
            { base: ['either state_id or passport must be present'],
              state_id_type: ['mis-matched type vs data'] }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )

            body = JSON.parse(response.body)
            expect(body['base'][0]).to eq(body_errors[:base][0])
          end
        end

        context 'when state_id and invalid residential address are provided' do
          let(:residential_address) { malformed_residential_address }
          let(:body_errors) { { zip_code: ['is invalid'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )

            body = JSON.parse(response.body)
            expect(body['zip_code'][0]).to eq(body_errors[:zip_code][0])
          end
        end

        context 'when both state_id and passport provided' do
          let(:id_type) { drivers_license_type }
          let(:state_id) { valid_state_id }
          let(:passport) { valid_passport }
          let(:residential_address) { valid_residential_address }
          let(:body_errors) { { base: ['cannot include both state_id and passport'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )

            body = JSON.parse(response.body)
            expect(body['base'][0]).to eq(body_errors[:base][0])
          end
        end
      end

      context 'when the id_type is state_id_card and with valid state_id data' do
        let(:id_type) { state_id_type }
        let(:state_id) { valid_state_id }

        context 'with a valid authorization header' do
          it 'returns 202' do
            expect(action.status).to eq(202)
            transaction_id = DocumentCaptureSession.last.uuid

            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(status: 'pending', transaction_id:),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
              remaining_attempts: a_kind_of(Integer),
            )
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('correlation-789')
          end

          context 'without proofing_location_id param' do
            let(:location_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_location_id: ['cannot be blank'] },
              )
            end
          end

          context 'without proofing_agent_id param' do
            let(:agent_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_agent_id: ['cannot be blank'] },
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:correlation_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: a_hash_including(
                  agent_id: 'agent-456',
                  location_id: 'loc-123',
                  correlation_id: nil,
                ),
                errors: missing_headers_errors,
              )
            end
          end

          context 'without any required headers' do
            let(:correlation_id) { nil }
            let(:agent_id) { nil }
            let(:location_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: a_hash_including(
                  agent_id: nil,
                  location_id: nil,
                  correlation_id: nil,
                ),
                errors: missing_headers_errors,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }
            let(:body_errors) { { first_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['first_name'][0]).to eq(body_errors[:first_name][0])
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }
            let(:body_errors) { { last_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['last_name'][0]).to eq(body_errors[:last_name][0])
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }
            let(:body_errors) { { dob: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob'][0]).to eq(body_errors[:dob][0])
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }
            let(:body_errors) { { dob_min_age: ['age does not meet minimum requirements'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob_min_age'][0]).to eq(body_errors[:dob_min_age][0])
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }
            let(:body_errors) { { address1: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['address1'][0]).to eq(body_errors[:address1][0])
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }
            let(:body_errors) { { zip_code: ['is invalid'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['zip_code'][0]).to eq(body_errors[:zip_code][0])
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }
            let(:body_errors) do
              { jurisdiction: ['cannot be blank', 'is not a valid state code'],
                state: ['cannot be blank', 'is not a valid state code'] }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['jurisdiction'][0]).to eq(body_errors[:jurisdiction][0])
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }
            let(:body_errors) { { document_number: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['document_number'][0]).to eq(body_errors[:document_number][0])
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }
            let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
            end
          end
        end
      end

      context 'when the id_type is identification_card and with valid state_id data' do
        let(:id_type) { identification_card_type }
        let(:state_id) { valid_state_id }

        context 'with a valid authorization header' do
          it 'returns 202' do
            expect(action.status).to eq(202)
            transaction_id = DocumentCaptureSession.last.uuid

            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(status: 'pending', transaction_id:),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
              remaining_attempts: a_kind_of(Integer),
            )
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end

          it 'returns the X-Correlation-ID header as correlation_id' do
            action
            expect(response.headers['X-Correlation-ID']).to eq('correlation-789')
          end

          context 'without proofing_location_id param' do
            let(:location_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_location_id: ['cannot be blank'] },
              )
            end
          end

          context 'without proofing_agent_id param' do
            let(:agent_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :body_validation,
                issuer:,
                proofing_agent: proofing_agent_analytics_hash,
                errors: { proofing_agent_id: ['cannot be blank'] },
              )
            end
          end

          context 'without X-Correlation-ID header' do
            let(:correlation_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: a_hash_including(
                  agent_id: 'agent-456',
                  location_id: 'loc-123',
                  correlation_id: nil,
                ),
                errors: missing_headers_errors,
              )
            end
          end

          context 'without any required headers' do
            let(:agent_id) { nil }
            let(:location_id) { nil }
            let(:correlation_id) { nil }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                success: false,
                failure_type: :header_validation,
                issuer:,
                proofing_agent: a_hash_including(
                  agent_id: nil,
                  location_id: nil,
                  correlation_id: nil,
                ),
                errors: missing_headers_errors,
              )
            end
          end

          context 'when the first_name is missing' do
            let(:first_name) { nil }
            let(:body_errors) { { first_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['first_name'][0]).to eq(body_errors[:first_name][0])
            end
          end

          context 'when the last_name is missing' do
            let(:last_name) { nil }
            let(:body_errors) { { last_name: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['last_name'][0]).to eq(body_errors[:last_name][0])
            end
          end

          context 'when the dob is missing' do
            let(:dob) { nil }
            let(:body_errors) { { dob: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob'][0]).to eq(body_errors[:dob][0])
            end
          end

          context 'when the dob does not meet our minimum age requirements' do
            let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }
            let(:body_errors) { { dob_min_age: ['age does not meet minimum requirements'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['dob_min_age'][0]).to eq(body_errors[:dob_min_age][0])
            end
          end

          context 'when the address1 is missing' do
            let(:address1) { nil }
            let(:body_errors) { { address1: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['address1'][0]).to eq(body_errors[:address1][0])
            end
          end

          context 'when the zip_code is invalid' do
            let(:zip_code) { '123456' }
            let(:body_errors) { { zip_code: ['is invalid'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['zip_code'][0]).to eq(body_errors[:zip_code][0])
            end
          end

          context 'when the jurisdiction is missing' do
            let(:jurisdiction) { nil }
            let(:body_errors) do
              { jurisdiction: ['cannot be blank', 'is not a valid state code'],
                state: ['cannot be blank', 'is not a valid state code'] }
            end

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['jurisdiction'][0]).to eq(body_errors[:jurisdiction][0])
            end
          end

          context 'when the document_number is missing' do
            let(:document_number) { nil }
            let(:body_errors) { { document_number: ['cannot be blank'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['document_number'][0]).to eq(body_errors[:document_number][0])
            end
          end

          context 'when the state_id is expired' do
            let(:expiration_date) { '2026-01-01' }
            let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

            it 'returns 400' do
              expect(action.status).to eq(400)
              expect(@analytics).to have_logged_event(
                :idv_proofing_agent_request_failed,
                **body_failure_event_attrs,
              )
              body = JSON.parse(response.body)
              expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
            end
          end
        end
      end

      context 'when the id_type is passport and with valid passport data' do
        let(:id_type) { passport_type }
        let(:passport) { valid_passport }
        let(:residential_address) { valid_residential_address }
        let(:user) { create(:user, email: 'foo@bar.com') }

        context 'when rate limit reached for the user' do
          before do
            RateLimiter.new(user:, rate_limit_type: :idv_resolution).increment_to_limited!
            RateLimiter.new(user:, rate_limit_type: :proof_ssn).increment_to_limited!
          end
          it 'returns 429 and logs events' do
            expect(action.status).to eq(429)
            expect(@analytics).to have_logged_event(
              'Rate Limit Reached',
              limiter_type: :idv_resolution,
              step_name: 'proof_user',
            )
            expect(@analytics).to have_logged_event(
              'Rate Limit Reached',
              limiter_type: :proof_ssn,
              step_name: 'proof_user',
            )
          end
        end

        context 'when valid passport data is received' do
          it 'returns 202' do
            expect(action.status).to eq(202)
            transaction_id = DocumentCaptureSession.last.uuid

            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(status: 'pending', transaction_id:),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
              remaining_attempts: a_kind_of(Integer),
            )
          end

          it 'includes correlation_id in the response' do
            action
            expect(response.headers['X-Correlation-ID']).to be_present
          end
        end

        context 'when the mrz is missing' do
          let(:mrz) { nil }
          let(:body_errors) { { mrz: ['cannot be blank'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['mrz'][0]).to eq(body_errors[:mrz][0])
          end
        end

        context 'when the passport is expired' do
          let(:expiration_date) { '2026-01-01' }
          let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
          end
        end

        context 'when the state_id is near expiration (2 days away)' do
          let(:expiration_date) { (Time.zone.today + 2.days).strftime('%Y-%m-%d') }
          let(:body_errors) { { expiration_date: ['is expired, or near expiration'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['expiration_date'][0]).to eq(body_errors[:expiration_date][0])
          end
        end

        context 'when the state_id is near expiration (3 days away)' do
          let(:expiration_date) { (Time.zone.today + 3.days).strftime('%Y-%m-%d') }
          let(:body_errors) { {} }

          it 'returns 202' do
            expect(action.status).to eq(202)
            expect(@analytics).not_to have_logged_event(:idv_proofing_agent_request_failed)
          end
        end

        context 'when the first_name is missing' do
          let(:first_name) { nil }
          let(:body_errors) { { first_name: ['cannot be blank'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['first_name'][0]).to eq(body_errors[:first_name][0])
          end
        end

        context 'when the last_name is missing' do
          let(:last_name) { nil }
          let(:body_errors) { { last_name: ['cannot be blank'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['last_name'][0]).to eq(body_errors[:last_name][0])
          end
        end

        context 'when the dob is missing' do
          let(:dob) { nil }
          let(:body_errors) { { dob: ['cannot be blank'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['dob'][0]).to eq(body_errors[:dob][0])
          end
        end

        context 'when the dob does not meet our minimum age requirements' do
          let(:dob) { (Time.zone.today - 10.years).strftime('%Y-%m-%d') }
          let(:body_errors) do
            { dob_min_age: ['age does not meet minimum requirements'] }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['dob_min_age'][0]).to eq(body_errors[:dob_min_age][0])
          end
        end

        context 'when the residential address is missing' do
          let(:residential_address) { nil }
          let(:body_errors) do
            { residential_address: ['residential address must be present with passport'] }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['residential_address'][0]).to eq(body_errors[:residential_address][0])
          end
        end

        context 'when the passport data is not provided' do
          let(:passport) { nil }
          let(:body_errors) do
            { base: ['either state_id or passport must be present'],
              passport_type: ['mis-matched type vs data'] }
          end

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )
            body = JSON.parse(response.body)
            expect(body['passport_type'][0]).to eq(body_errors[:passport_type][0])
          end
        end

        context 'when the id_type is passport_card' do
          let(:id_type) { passport_card_type }
          let(:body_errors) { { unknown_id_type: ['unsupported id_type'] } }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              **body_failure_event_attrs,
            )

            body = JSON.parse(response.body)
            expect(body['unknown_id_type'][0]).to eq(body_errors[:unknown_id_type][0])
          end
        end
      end
    end
  end

  describe '#result' do
    before { stub_analytics }

    let(:transaction_id) { 'a-transaction-uuid' }
    let(:action) do
      post :result, params: {
        proofing_agent_id: agent_id,
        proofing_location_id: location_id,
        transaction_id:,
      }.compact
    end

    let(:successful_proofing_result) do
      Idv::ProofingAgent::AgentProofedUser.new(
        id: SecureRandom.uuid,
        success: true,
        reason: nil,
        transaction_id:,
      )
    end

    let(:failed_proofing_result) do
      Idv::ProofingAgent::AgentProofedUser.new(
        id: SecureRandom.uuid,
        success: false,
        reason: 'id_fail',
        transaction_id:,
      )
    end

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'with an invalid authorization header' do
        it_behaves_like 'an endpoint that requires authorization'
      end

      context 'with a valid authorization header' do
        context 'without X-Correlation-ID header' do
          let(:correlation_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :header_validation,
              issuer:,
              proofing_agent: a_hash_including(correlation_id: nil),
              errors: missing_headers_errors,
            )
          end
        end

        context 'without proofing_agent_id param' do
          let(:agent_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :body_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: { proofing_agent_id: ['cannot be blank'] },
            )
          end
        end

        context 'without proofing_location_id param' do
          let(:location_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :body_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: { proofing_location_id: ['cannot be blank'] },
            )
          end
        end

        context 'without transaction_id param' do
          let(:transaction_id) { nil }

          it 'returns 400' do
            expect(action.status).to eq(400)
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_failed,
              success: false,
              failure_type: :body_validation,
              issuer:,
              proofing_agent: proofing_agent_analytics_hash,
              errors: { transaction_id: ['cannot be blank'] },
            )
          end
        end

        context 'when a DocumentCaptureSession exists but the proofing result is not yet ready' do
          before do
            DocumentCaptureSession.create!(uuid: transaction_id, user_id: user.id, issuer:)
          end

          it 'returns 404 with not_found reason' do
            expect(action.status).to eq(404)

            body = JSON.parse(response.body)
            expect(body['success']).to eq(false)
            expect(body['reason']).to eq('result_not_found')
            expect(body['transaction_id']).to eq(transaction_id)
          end
        end

        context 'when there is a successful proofing result' do
          before do
            session = DocumentCaptureSession.create!(
              uuid: transaction_id,
              user_id: user.id,
              issuer:,
            )
            allow(session)
              .to receive(:load_agent_proofed_user)
              .and_return(successful_proofing_result)
            allow(DocumentCaptureSession).to receive(:find_by).with(uuid: transaction_id)
              .and_return(session)
          end

          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'returns a true success and the transaction_id in the body' do
            action
            body = JSON.parse(response.body)
            expect(body['success']).to eq(true)
            expect(body['reason']).to be_nil
            expect(body['transaction_id']).to eq(transaction_id)
          end

          it 'logs the analytics event' do
            action
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(
                success: true,
                transaction_id:,
              ),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
            )
          end

          it 'echoes the X-Correlation-ID in the response headers' do
            action
            expect(response.headers['X-Correlation-ID']).to eq(correlation_id)
          end
        end

        context 'when there is a failed proofing result' do
          before do
            session = DocumentCaptureSession.create!(
              uuid: transaction_id,
              user_id: user.id,
              issuer:,
            )
            allow(session).to receive(:load_agent_proofed_user).and_return(failed_proofing_result)
            allow(DocumentCaptureSession).to receive(:find_by).with(uuid: transaction_id)
              .and_return(session)
          end

          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'returns a false success and the failure reason in the body' do
            action
            body = JSON.parse(response.body)
            expect(body['success']).to eq(false)
            expect(body['reason']).to eq('id_fail')
            expect(body['transaction_id']).to eq(transaction_id)
          end

          it 'logs the analytics event' do
            action
            expect(@analytics).to have_logged_event(
              :idv_proofing_agent_request_received,
              response_body: a_hash_including(
                success: false,
                reason: 'id_fail',
                transaction_id:,
              ),
              proofing_agent: proofing_agent_analytics_hash,
              issuer:,
              transaction_id:,
            )
          end
        end

        context 'when the result is cached' do
          before do
            session = DocumentCaptureSession.create!(
              uuid: transaction_id,
              user_id: user.id,
              issuer:,
            )
            allow(session)
              .to receive(:load_agent_proofed_user)
              .and_return(successful_proofing_result)
            allow(DocumentCaptureSession).to receive(:find_by).with(uuid: transaction_id)
              .and_return(session)
          end

          it 'only calls load_agent_proofed_user once across two requests' do
            session = DocumentCaptureSession.find_by(uuid: transaction_id)
            expect(session)
              .to receive(:load_agent_proofed_user)
              .once.and_return(successful_proofing_result)
            allow(DocumentCaptureSession).to receive(:find_by).with(uuid: transaction_id)
              .and_return(session)

            post :result, params: { proofing_agent_id: agent_id,
                                    proofing_location_id: location_id,
                                    transaction_id: }
            post :result, params: { proofing_agent_id: agent_id,
                                    proofing_location_id: location_id,
                                    transaction_id: }
          end
        end
      end
    end
  end
end
