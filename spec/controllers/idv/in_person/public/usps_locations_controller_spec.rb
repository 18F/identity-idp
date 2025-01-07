require 'rails_helper'

RSpec.describe Idv::InPerson::Public::UspsLocationsController do
  include Rails.application.routes.url_helpers

  before do
    stub_analytics
  end

  describe '#index' do
    subject(:action) do
      post :index,
           params: {
             address: {
               address: '87060 Colby Radial, Stephenmouth, OK 73339-7909',
               zip_code: '73339',
               state: 'OK',
               city: 'Stephenmouth',
               street_address: '87060 Colby Radial',
             },
           }
    end

    it 'is successful and has a response' do
      action
      expect(response).to be_ok
    end

    context 'with a 500 error from USPS' do
      let(:server_error) { Faraday::ServerError.new }
      let(:proofer) { double('Proofer') }

      before do
        allow(UspsInPersonProofing::EnrollmentHelper).to receive(:usps_proofer).and_return(proofer)
        allow(proofer).to receive(:request_facilities).and_raise(server_error)
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

    context 'address has unsupported characters' do
      let(:locale) { nil }
      let(:usps_locations_error) { Idv::InPerson::Public::UspsLocationsError.new }

      subject(:response) do
        post :index, params: { locale: locale,
                               address: { street_address: '1600, Pennsylvania Ave',
                                          city: 'Washington',
                                          state: 'DC',
                                          zip_code: '20500' } }
      end

      it 'returns unprocessable entity' do
        subject

        expect(@analytics).to have_logged_event(
          'Request USPS IPP locations: request failed',
          api_status_code: 422,
          exception_class: usps_locations_error.class,
          exception_message: usps_locations_error.message,
          response_body_present: false,
          response_body: false,
          response_status_code: false,
        )

        expect(response.status).to eq 422
      end
    end
  end
end
