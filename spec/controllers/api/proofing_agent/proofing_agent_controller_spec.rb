# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ProofingAgent::ProofingAgentController do
  let(:enabled) { false }

  let(:drivers_license_type) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }
  let(:passport_type) { Idp::Constants::DocumentTypes::PASSPORT }
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
    allow(FeatureManagement).to receive(:idv_proofing_agent_enabled?).and_return(enabled)
    allow(controller).to receive(:params).and_return(agent_params)
  end

  describe '#search_user' do
    let(:action) { post :search_user }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      it 'returns 200' do
        expect(action.status).to eq(200)
      end

      it 'includes request_id in the response' do
        action
        body = JSON.parse(response.body)
        expect(body['request_id']).to be_present
      end
    end
  end

  describe '#proof_user' do
    let(:action) { post :proof_user }

    context 'when proofing agent is not enabled' do
      it 'returns 404' do
        expect(action.status).to eq(404)
      end
    end

    context 'when proofing agent is enabled' do
      let(:enabled) { true }

      context 'when the id_type is drivers_licence' do
        let(:id_type) { drivers_license_type }
        let(:state_id) { valid_state_id }

        context 'when valid state id data is received' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes request_id in the response' do
            action
            body = JSON.parse(response.body)
            expect(body['request_id']).to be_present
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

      context 'when the id_type is passport' do
        let(:id_type) { passport_type }
        let(:passport) { valid_passport }
        let(:residential_address) { valid_residential_address }

        context 'when valid passport data is received' do
          it 'returns 200' do
            expect(action.status).to eq(200)
          end

          it 'includes request_id in the response' do
            action
            body = JSON.parse(response.body)
            expect(body['request_id']).to be_present
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
      end
    end
  end
end
