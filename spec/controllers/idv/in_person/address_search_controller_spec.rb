require 'rails_helper'

RSpec.describe Idv::InPerson::AddressSearchController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:sp) { nil }

  before do
    stub_analytics
    stub_sign_in(user) if user
    allow(controller).to receive(:current_sp).and_return(sp)
  end

  describe '#index' do
    let(:geocoder) { double('Geocoder') }

    let(:addresses) do
      [
        { name: 'Address 1' },
        { name: 'Address 2' },
        { name: 'Address 3' },
        { name: 'Address 4' },
      ]
    end
    subject(:response) { get :index }

    before do
      allow(controller).to receive(:geocoder).and_return(geocoder)
      allow(geocoder).to receive(:find_address_candidates).and_return(addresses)
    end

    context 'with successful fetch' do
      it 'gets successful response' do
        response = get :index
        expect(response.status).to eq(200)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 1
      end

      context 'with no address candidates' do
        let(:addresses) do
          []
        end

        it 'returns empty array' do
          response = get :index
          expect(response.status).to eq(200)
          addresses = JSON.parse(response.body)
          expect(addresses.length).to eq 0
          expect(@analytics).to have_logged_event(
            'IdV: in person proofing location search submitted',
            success: false,
            errors: 'No address candidates found by ArcGIS',
            result_total: 0,
            exception_class: nil,
            exception_message: nil,
            response_status_code: nil,
          )
        end
      end

      context 'with error code' do
        let(:response_body) do
          { 'error' => {
            'code' => 400,
            'details' => ['request is too many characters'],
            'message' => 'Unable to complete operation.',
          } }
        end
        let(:parsed_response_body) { { details: response_body['error']['details'].join(', ') } }

        before do
          exception = Faraday::ClientError.new(
            RuntimeError.new(response_body['error']['message']),
            {
              status: response_body['error']['code'],
              body: parsed_response_body,
            },
          )
          allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
        end

        it 'logs analytics event' do
          response = get :index
          addresses = JSON.parse(response.body)
          expect(addresses.length).to eq 0
          expect(@analytics).to have_logged_event(
            'IdV: in person proofing location search submitted',
            api_status_code: 422,
            success: false,
            errors: 'request is too many characters',
            result_total: 0,
            exception_class: Faraday::ClientError,
            exception_message: 'Unable to complete operation.',
            response_status_code: 400,
          )
        end

        context 'with malformed response body details' do
          let(:parsed_response_body) { response_body['error']['details'] }

          it 'logs analytics event' do
            response = get :index
            addresses = JSON.parse(response.body)
            expect(addresses.length).to eq 0
            expect(@analytics).to have_logged_event(
              'IdV: in person proofing location search submitted',
              api_status_code: 422,
              success: false,
              errors: 'ArcGIS error performing operation',
              result_total: 0,
              exception_class: Faraday::ClientError,
              exception_message: 'Unable to complete operation.',
              response_status_code: 400,
            )
          end
        end
      end
    end

    context 'with connection failed exception' do
      before do
        exception = Faraday::ConnectionFailed.new('connection failed')
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'gets an empty pilot response' do
        response = get :index
        expect(response.status).to eq(422)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0
      end

      it 'logs search analytics' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          api_status_code: 422,
          success: false,
          errors: 'ArcGIS error performing operation',
          result_total: 0,
          exception_class: Faraday::ConnectionFailed,
          exception_message: 'connection failed',
          response_status_code: nil,
        )
      end
    end

    context 'with invalid authenticity token exception' do
      before do
        exception = ActionController::InvalidAuthenticityToken.new('invalid token')
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'gets an empty pilot response' do
        response = get :index
        expect(response.status).to eq(422)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0
      end

      it 'logs search analytics' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          api_status_code: 422,
          success: false,
          errors: 'ArcGIS error performing operation',
          result_total: 0,
          exception_class: ActionController::InvalidAuthenticityToken,
          exception_message: 'invalid token',
          response_status_code: nil,
        )
      end
    end

    context 'with a timeout error' do
      let(:server_error) { Faraday::TimeoutError.new }

      before do
        stub_analytics
        exception = Faraday::TimeoutError.new
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'returns an error code' do
        response = get :index
        expect(response.status).to eq(422)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0

        expect(@analytics).to have_logged_event(
          'Request ArcGIS Address Candidates: request failed',
          api_status_code: response.status,
          exception_class: server_error.class,
          exception_message: server_error.message,
          response_body_present:
          server_error.response_body.present?,
          response_body: server_error.response_body,
          response_status_code: server_error.response_status,
        )
      end

      it 'logs search analytics' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          api_status_code: 422,
          success: false,
          errors: 'ArcGIS error performing operation',
          result_total: 0,
          exception_class: Faraday::TimeoutError,
          exception_message: 'timeout',
          response_status_code: nil,
        )
      end
    end

    context 'with an error' do
      before do
        exception = StandardError.new('error')
        allow(geocoder).to receive(:find_address_candidates).and_raise(exception)
      end

      it 'returns a 500 error code' do
        response = get :index
        expect(response.status).to eq(500)
        addresses = JSON.parse(response.body)
        expect(addresses.length).to eq 0
      end

      it 'logs search analytics' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          api_status_code: 500,
          success: false,
          errors: 'ArcGIS error performing operation',
          result_total: 0,
          exception_class: StandardError,
          exception_message: 'error',
          response_status_code: nil,
        )
      end

      it 'logs the arcgis request failure' do
        get :index
        expect(@analytics).to have_logged_event(
          'Request ArcGIS Address Candidates: request failed',
          api_status_code: 500,
          exception_class: StandardError,
          exception_message: 'error',
          response_status_code: nil,
          response_body_present: false,
          response_body: false,
        )
      end
    end
  end
end
