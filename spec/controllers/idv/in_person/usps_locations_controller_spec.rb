require 'rails_helper'

RSpec.describe Idv::InPerson::UspsLocationsController do
  include IdvHelper

  let(:user) { create(:user) }
  let(:sp) { nil }
  let(:in_person_proofing_enabled) { true }
  let(:empty_locations) { [] }
  let(:address) do
    UspsInPersonProofing::Applicant.new(
      address: '1600 Pennsylvania Ave',
      city: 'Washington', state: 'DC', zip_code: '20500'
    )
  end
  let(:fake_address) do
    UspsInPersonProofing::Applicant.new(
      address: '742 Evergreen Terrace',
      city: 'Springfield', state: 'MO', zip_code: '89011'
    )
  end
  let(:selected_location) do
    {
      usps_location: {
        formatted_city_state_zip: 'BALTIMORE, MD, 21233-9715',
        name: 'BALTIMORE',
        saturday_hours: '8:30 AM - 5:00 PM',
        street_address: '123 Fake St.',
        sunday_hours: 'Closed',
        weekday_hours: '8:30 AM - 7:00 PM',
      },
    }
  end

  before do
    stub_analytics
    stub_sign_in(user) if user
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(controller).to receive(:current_sp).and_return(sp)
  end

  describe '#index' do
    let(:proofer) { double('Proofer') }
    let(:locations) do
      [
        { address: '3118 WASHINGTON BLVD',
          city: 'ARLINGTON',
          distance: '6.02 mi',
          name: 'ARLINGTON',
          saturday_hours: '9:00 AM - 1:00 PM',
          state: 'VA',
          sunday_hours: 'Closed',
          weekday_hours: '9:00 AM - 5:00 PM',
          zip_code_4: '9998',
          zip_code_5: '22201' },
        { address: '4005 WISCONSIN AVE NW',
          city: 'WASHINGTON',
          distance: '6.59 mi',
          name: 'FRIENDSHIP',
          saturday_hours: '8:00 AM - 4:00 PM',
          state: 'DC',
          sunday_hours: '10:00 AM - 4:00 PM',
          weekday_hours: '8:00 AM - 6:00 PM',
          zip_code_4: '9997',
          zip_code_5: '20016' },
        { address: '6900 WISCONSIN AVE STE 100',
          city: 'CHEVY CHASE',
          distance: '8.99 mi',
          name: 'BETHESDA',
          saturday_hours: '9:00 AM - 4:00 PM',
          state: 'MD',
          sunday_hours: 'Closed',
          weekday_hours: '9:00 AM - 5:00 PM',
          zip_code_4: '9996',
          zip_code_5: '20815' },
      ]
    end
    let(:pilot_locations) do
      [
        { name: 'Location 1' },
        { name: 'Location 2' },
        { name: 'Location 3' },
        { name: 'Location 4' },
      ]
    end
    subject(:response) do
      post :index, params: { address: { street_address: '1600 Pennsylvania Ave',
                                        city: 'Washington',
                                        state: 'DC',
                                        zip_code: '20500' } }
    end

    before do
      allow(UspsInPersonProofing::Proofer).to receive(:new).and_return(proofer)
    end

    context 'with a nil address in params' do
      let(:param_error) { ActionController::ParameterMissing.new(param: address) }

      before do
        allow(proofer).to receive(:request_facilities).with(address).and_raise(param_error)
      end

      subject(:response) do
        post :index, params: { address: nil }
      end

      it 'returns no locations' do
        subject
        json = response.body
        facilities = JSON.parse(json)
        expect(facilities.length).to eq 0
      end
    end

    context 'no addresses found by usps' do
      before do
        allow(proofer).to receive(:request_facilities).with(address).and_return(empty_locations)
      end

      it 'logs analytics with error when successful response is empty' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          success: false,
          errors: 'No USPS locations found',
          result_total: 0,
          exception_class: nil,
          exception_message: nil,
          response_status_code: nil,
        )
      end
    end

    context 'with successful fetch' do
      before do
        allow(proofer).to receive(:request_facilities).with(address).and_return(locations)
      end

      it 'returns a successful response' do
        json = response.body
        facilities = JSON.parse(json)
        expect(facilities.length).to eq 3
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          success: true,
          errors: nil,
          result_total: 3,
          exception_class: nil,
          exception_message: nil,
          response_status_code: nil,
        )
      end
    end

    context 'with a timeout from Faraday' do
      let(:timeout_error) { Faraday::TimeoutError.new }

      before do
        allow(proofer).to receive(:request_facilities).with(address).and_raise(timeout_error)
      end

      it 'returns an unprocessible entity client error' do
        subject
        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: timeout_error.class,
          exception_message: timeout_error.message,
          response_body_present:
          timeout_error.response_body.present?,
          response_body: timeout_error.response_body,
          response_status_code: timeout_error.response_status,
        )

        status = response.status
        expect(status).to eq 422
      end
    end

    context 'with a 500 error from USPS' do
      let(:server_error) { Faraday::ServerError.new }

      before do
        allow(proofer).to receive(:request_facilities).with(address).and_raise(server_error)
      end

      it 'returns an unprocessible entity client error' do
        subject
        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: server_error.class,
          exception_message: server_error.message,
          response_body_present:
          server_error.response_body.present?,
          response_body: server_error.response_body,
          response_status_code: server_error.response_status,
        )

        status = response.status
        expect(status).to eq 422
      end
    end

    context 'with failed connection to Faraday' do
      let(:exception) { Faraday::ConnectionFailed.new }
      subject(:response) do
        post :index,
             params: { address: { street_address: '742 Evergreen Terrace',
                                  city: 'Springfield',
                                  state: 'MO',
                                  zip_code: '89011' } }
      end

      before do
        allow(proofer).to receive(:request_facilities).with(fake_address).and_raise(exception)
      end

      it 'returns no locations' do
        subject
        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: exception.class,
          exception_message: exception.message,
          response_body_present:
          exception.response_body.present?,
          response_body: exception.response_body,
          response_status_code: exception.response_status,
        )

        facilities = JSON.parse(response.body)
        expect(facilities.length).to eq 0
      end
    end

    context 'with in person proofing disabled' do
      let(:in_person_proofing_enabled) { false }

      it 'renders 404' do
        expect(response.status).to eq(404)
      end
    end
  end

  describe '#update' do
    subject(:response) { put :update, params: selected_location }

    it 'writes the passed location to in-person enrollment' do
      response

      enrollment = user.reload.establishing_in_person_enrollment

      expect(enrollment.selected_location_details).to eq(selected_location[:usps_location].as_json)
      expect(enrollment.service_provider).to be_nil
    end

    it 'updates proofing component vendor' do
      expect(user.proofing_component&.document_check).to be_nil

      response

      expect(user.proofing_component.document_check).to eq Idp::Constants::Vendors::USPS
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it 'renders an unauthorized status' do
        expect(response.status).to eq(401)
      end
    end

    context 'with associated service provider' do
      let(:sp) { create(:service_provider) }

      it 'assigns services provider to in-person enrollment' do
        response

        enrollment = user.reload.establishing_in_person_enrollment

        expect(enrollment.issuer).to eq(sp.issuer)
      end
    end

    context 'with hybrid user' do
      let(:user) { nil }
      let(:effective_user) { create(:user) }

      before do
        session[:doc_capture_user_id] = effective_user.id
      end

      it 'writes the passed location to in-person enrollment associated with effective user' do
        response

        enrollment = effective_user.reload.establishing_in_person_enrollment

        expect(enrollment.selected_location_details).to eq(
          selected_location[:usps_location].as_json,
        )
        expect(enrollment.service_provider).to be_nil
      end
    end

    context 'with feature disabled' do
      let(:in_person_proofing_enabled) { false }

      it 'renders 404' do
        expect(response.status).to eq(404)
      end
    end
  end
end
