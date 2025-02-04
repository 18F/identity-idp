require 'rails_helper'

RSpec.describe Idv::InPerson::UspsLocationsController do
  let(:user) { create(:user) }
  let(:sp) { nil }
  let(:in_person_proofing_enabled) { true }
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
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    allow(controller).to receive(:current_sp).and_return(sp)
  end

  describe '#index' do
    let(:locale) { nil }
    let(:proofer) { double('Proofer') }
    let(:locations) do
      [
        UspsInPersonProofing::PostOffice.new(
          address: '3118 WASHINGTON BLVD',
          city: 'ARLINGTON',
          distance: '6.02 mi',
          name: 'ARLINGTON',
          saturday_hours: '9:00 AM - 1:00 PM',
          state: 'VA',
          sunday_hours: 'Closed',
          weekday_hours: '9:00 AM - 5:00 PM',
          zip_code_4: '9998',
          zip_code_5: '22201',
        ),
        UspsInPersonProofing::PostOffice.new(
          address: '4005 WISCONSIN AVE NW',
          city: 'WASHINGTON',
          distance: '6.59 mi',
          name: 'FRIENDSHIP',
          saturday_hours: '8:00 AM - 4:00 PM',
          state: 'DC',
          sunday_hours: '10:00 AM - 4:00 PM',
          weekday_hours: '8:00 AM - 6:00 PM',
          zip_code_4: '9997',
          zip_code_5: '20016',
        ),
        UspsInPersonProofing::PostOffice.new(
          address: '6900 WISCONSIN AVE STE 100',
          city: 'CHEVY CHASE',
          distance: '8.99 mi',
          name: 'BETHESDA',
          saturday_hours: '9:00 AM - 4:00 PM',
          state: 'MD',
          sunday_hours: 'Closed',
          weekday_hours: '9:00 AM - 5:00 PM',
          zip_code_4: '9996',
          zip_code_5: '20815',
        ),
      ]
    end
    subject(:response) do
      post :index, params: { locale: locale,
                             address: { street_address: '1600 Pennsylvania Ave',
                                        city: 'Washington',
                                        state: 'DC',
                                        zip_code: '20500' } }
    end

    before do
      allow(UspsInPersonProofing::Proofer).to receive(:new).and_return(proofer)
    end

    context 'with a user going through enhanced ipp' do
      let(:vtr) { ['C1.C2.P1.Pe'] }
      let(:enhanced_ipp_sp_session) { { vtr: vtr, acr_values: nil } }
      let(:user) { build(:user) }
      let(:sp) { build(:service_provider, ial: 2) }

      before do
        allow(controller).to receive(:sp_session).and_return(enhanced_ipp_sp_session)
        allow(controller).to receive(:sp_from_sp_session).and_return(sp)
      end

      it 'requests enhanced ipp locations' do
        expect(AuthnContextResolver).to receive(:new).with(
          user: user, service_provider: sp,
          vtr: vtr, acr_values: nil
        ).and_call_original
        expect(proofer).to receive(:request_facilities).with(address, true)

        subject
      end
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

    context 'address has unsupported characters' do
      subject(:response) do
        post :index, params: { locale: locale,
                               address: { street_address: '1600, Pennsylvania Ave',
                                          city: 'Washington',
                                          state: 'DC',
                                          zip_code: '20500' } }
      end

      it 'returns unprocessable entity' do
        subject
        expect(response.status).to eq 422
      end
    end

    context 'no addresses found by usps' do
      before do
        allow(proofer).to receive(:request_facilities).with(address, false)
          .and_return([])
      end

      it 'logs analytics with error when successful response is empty' do
        response
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          success: false,
          errors: 'No USPS locations found',
          result_total: 0,
        )
      end
    end

    context 'with successful fetch' do
      before do
        allow(proofer).to receive(:request_facilities).with(address, false).and_return(locations)
      end

      it 'returns a successful response' do
        json = response.body
        facilities = JSON.parse(json)
        expect(facilities.length).to eq 3
        expect(@analytics).to have_logged_event(
          'IdV: in person proofing location search submitted',
          success: true,
          result_total: 3,
        )
      end
    end

    context 'with a timeout from Faraday' do
      let(:timeout_error) { Faraday::TimeoutError.new }

      before do
        allow(proofer).to receive(:request_facilities).with(address, false).and_raise(timeout_error)
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
        )

        status = response.status
        expect(status).to eq 422
      end
    end

    context 'with a 500 error from USPS' do
      let(:server_error) { Faraday::ServerError.new }

      before do
        allow(proofer).to receive(:request_facilities).with(address, false).and_raise(server_error)
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
        allow(proofer).to receive(:request_facilities).with(fake_address, false)
          .and_raise(exception)
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

    context 'with 400 error from USPS for sponsor id not found' do
      let(:response_message) { 'Sponsor for sponsorID 5 not found' }
      let(:response_body) { { responseMessage: response_message } }
      let(:error_response) { { body: response_body, status: 400 } }
      let(:sponsor_id_error) { Faraday::BadRequestError.new(response_message, error_response) }
      let(:filtered_message) { 'Sponsor for sponsorID [FILTERED] not found' }

      before do
        allow(proofer).to receive(:request_facilities).and_raise(sponsor_id_error)
      end

      it 'returns an unprocessible entity client error with scrubbed analytics event' do
        subject

        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: sponsor_id_error.class,
          exception_message: filtered_message,
          response_body_present: true,
          response_body: { responseMessage: filtered_message },
          response_status_code: 400,
        )

        status = response.status
        expect(status).to eq 422
      end
    end

    context 'with 400 error because sponsor id is not registered as an ipp client' do
      let(:response_message) { 'SponsorID 57 is not registered as an IPP client' }
      let(:response_body) { { responseMessage: response_message } }
      let(:error_response) { { body: response_body, status: 400 } }
      let(:sponsor_id_error) { Faraday::BadRequestError.new(response_message, error_response) }
      let(:filtered_message) { 'sponsorID [FILTERED] is not registered as an IPP client' }

      before do
        allow(proofer).to receive(:request_facilities).and_raise(sponsor_id_error)
      end

      it 'returns an unprocessible entity client error with scrubbed analytics event' do
        subject

        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: sponsor_id_error.class,
          exception_message: filtered_message,
          response_body_present: true,
          response_body: { responseMessage: filtered_message },
          response_status_code: 400,
        )

        status = response.status
        expect(status).to eq 422
      end
    end

    context 'with 400 error without a response message' do
      let(:response_message) { 'SponsorID 57 is not registered as an IPP client' }
      let(:response_body) { { differentMessage: 'Something else is wrong' } }
      let(:error_response) { { body: response_body, status: 400 } }
      let(:sponsor_id_error) { Faraday::BadRequestError.new(response_message, error_response) }
      let(:filtered_message) { 'sponsorID [FILTERED] is not registered as an IPP client' }

      before do
        allow(proofer).to receive(:request_facilities).and_raise(sponsor_id_error)
      end

      it 'returns an unprocessible entity client error with scrubbed analytics event' do
        subject

        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: sponsor_id_error.class,
          exception_message: filtered_message,
          response_body_present: true,
          response_body: response_body,
          response_status_code: 400,
        )

        status = response.status
        expect(status).to eq 422
      end
    end
  end

  describe '#update' do
    let(:enrollment) { InPersonEnrollment.last }
    let(:sp) { create(:service_provider, ial: 2) }
    subject(:response) { put :update, params: selected_location }

    context 'when the user is going through ID-IPP' do
      it 'creates an in person enrollment' do
        expect { response }.to change { InPersonEnrollment.count }.from(0).to(1)
        expect(enrollment.user).to eq(user)
        expect(enrollment.status).to eq('establishing')
        expect(enrollment.profile).to be_nil
        expect(enrollment.sponsor_id).to eq(IdentityConfig.store.usps_ipp_sponsor_id)
        expect(enrollment.selected_location_details).to eq(
          selected_location[:usps_location].as_json,
        )
        expect(enrollment.service_provider).to eq(sp)
      end
    end

    context 'when the user is going through EIPP' do
      let(:vtr) { ['C1.C2.P1.Pe'] }
      let(:enhanced_ipp_sp_session) { { vtr: vtr, acr_values: nil } }

      before do
        allow(controller).to receive(:sp_session).and_return(enhanced_ipp_sp_session)
        allow(controller).to receive(:sp_from_sp_session).and_return(sp)
      end

      it 'creates an in person enrollment' do
        expect { response }.to change { InPersonEnrollment.count }.from(0).to(1)
        expect(enrollment.user).to eq(user)
        expect(enrollment.status).to eq('establishing')
        expect(enrollment.profile).to be_nil
        expect(enrollment.sponsor_id).to eq(IdentityConfig.store.usps_eipp_sponsor_id)
        expect(enrollment.selected_location_details).to eq(
          selected_location[:usps_location].as_json,
        )
        expect(enrollment.service_provider).to eq(sp)
      end
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
      let(:hybrid_user) { create(:user) }

      before do
        session[:doc_capture_user_id] = hybrid_user.id
      end

      it 'writes the passed location to in-person enrollment associated with effective user' do
        response

        enrollment = hybrid_user.reload.establishing_in_person_enrollment

        expect(enrollment.selected_location_details).to eq(
          selected_location[:usps_location].as_json,
        )
        expect(enrollment.service_provider).to eq(sp)
      end
    end

    context 'with failed doc_auth_result' do
      before do
        allow(controller).to receive(:document_capture_session).and_return(
          DocumentCaptureSession.new(last_doc_auth_result: 'Failed'),
        )
      end

      it 'updates the doc_auth_result in the enrollment' do
        response

        enrollment = user.reload.establishing_in_person_enrollment

        expect(enrollment.selected_location_details).to_not be_nil
        expect(enrollment.doc_auth_result).to eq('Failed')
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
