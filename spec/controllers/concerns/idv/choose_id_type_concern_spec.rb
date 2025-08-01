require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeConcern, :controller do
  controller ApplicationController do
    include Idv::ChooseIdTypeConcern
  end

  subject { controller }

  let(:analytics) { FakeAnalytics.new }
  let(:step) { 'choose_id_type' }
  let(:document_capture_session) { double(DocumentCaptureSession) }
  let(:fetch_arguments) do
    {
      analytics:,
      step:,
    }
  end
  let(:parameters) do
    ActionController::Parameters.new(
      {
        doc_auth: {
          choose_id_type_preference: id_type,
        },
      },
    )
  end

  before do
    allow(controller).to receive(:document_capture_session).and_return(document_capture_session)
  end

  describe '#chosen_id_type' do
    let(:id_type) { 'passport' }

    before do
      allow(controller).to receive(:params).and_return(parameters)
    end

    it 'returns the choose_id_type_prefence from params' do
      expect(subject.chosen_id_type).to eq(id_type)
    end
  end

  describe '#set_passport_requested' do
    before do
      allow(document_capture_session).to receive(:update!)
    end

    context 'when chosen_id_type is "passport"' do
      let(:id_type) { 'passport' }

      before do
        allow(controller).to receive(:params).and_return(parameters)
        subject.set_passport_requested
      end

      it 'updates the document_capture_session passport status to "requested"' do
        expect(document_capture_session).to have_received(:update!).with(
          passport_status: 'requested',
        )
      end
    end

    context 'when chosen_id_type is not "passport"' do
      let(:id_type) { 'drivers_license' }

      before do
        allow(controller).to receive(:params).and_return(parameters)
        subject.set_passport_requested
      end

      it 'updates the document_capture_session passport status to "not_requested"' do
        expect(document_capture_session).to have_received(:update!).with(
          passport_status: 'not_requested',
        )
      end
    end
  end

  describe '#choose_id_type_form_params' do
    context 'when the parameters has allowed params' do
      let(:id_type) { 'passport' }

      before do
        allow(controller).to receive(:params).and_return(parameters)
      end

      it 'returns the allowed choose_id_type form params' do
        expect(subject.choose_id_type_form_params).to have_key(:choose_id_type_preference)
      end
    end

    context 'when the parameters has non allowed params' do
      let(:invalid_params) do
        ActionController::Parameters.new(
          {
            doc_auth: {
              invalid: 'I am error',
            },
          },
        )
      end

      before do
        allow(controller).to receive(:params).and_return(invalid_params)
      end

      it 'does not return invalid choose_id_type form params' do
        expect(subject.choose_id_type_form_params).to_not have_key(:invalid)
      end
    end
  end

  describe '#selected_id_type' do
    before do
      allow(document_capture_session).to receive(:passport_status).and_return(passport_status)
    end

    context 'when the document capture session passport status is "requested"' do
      let(:passport_status) { 'requested' }

      it 'returns :passport' do
        expect(subject.selected_id_type).to eq(:passport)
      end
    end

    context 'when the document capture session passport status is "not_requested"' do
      let(:passport_status) { 'not_requested' }

      it 'returns :drivers_license' do
        expect(subject.selected_id_type).to eq(:drivers_license)
      end
    end

    context 'when the document capture session passport status is "allowed"' do
      let(:passport_status) { 'allowed' }

      it 'returns nil' do
        expect(subject.selected_id_type).to be_nil
      end
    end
  end

  describe '#dos_passport_api_healthy?' do
    context 'when the endpoint is set' do
      let(:request) { double(DocAuth::Dos::Requests::HealthCheckRequest) }
      let(:response) { double(DocAuth::Dos::Responses::HealthCheckResponse) }

      before do
        allow(IdentityConfig.store).to receive(
          :dos_passport_composite_healthcheck_endpoint,
        ).and_return('http://dostest.com/status')
        allow(DocAuth::Dos::Requests::HealthCheckRequest).to receive(:new).and_return(request)
        allow(request).to receive(:fetch).with(analytics, step).and_return(response)
      end

      context 'when the dos response is successful' do
        before do
          allow(response).to receive(:success?).and_return(true)
        end

        it 'returns true' do
          expect(subject.dos_passport_api_healthy?(analytics:, step:)).to be(true)
        end
      end

      context 'when the dos response is a failure' do
        before do
          allow(response).to receive(:success?).and_return(false)
        end

        it 'returns false' do
          expect(subject.dos_passport_api_healthy?(analytics:, step:)).to be(false)
        end
      end
    end

    context 'when the endpoint is an empty string' do
      it 'returns true' do
        expect(subject.dos_passport_api_healthy?(analytics:, step:, endpoint: '')).to be(true)
      end
    end
  end

  describe '#locals_attrs' do
    let(:presenter) { double(Idv::ChooseIdTypePresenter) }
    let(:form_submit_url) { '/verify/choose_id_type' }
    let(:request) { double(DocAuth::Dos::Requests::HealthCheckRequest) }
    let(:response) { double(DocAuth::Dos::Responses::HealthCheckResponse) }

    before do
      allow(IdentityConfig.store).to receive(
        :dos_passport_composite_healthcheck_endpoint,
      ).and_return('http://dostest.com/status')
      allow(DocAuth::Dos::Requests::HealthCheckRequest).to receive(:new).and_return(request)
      allow(request).to receive(:fetch).with(analytics, step).and_return(response)
    end

    context 'when the dos passport api is healthy' do
      before do
        allow(response).to receive(:success?).and_return(true)
        allow(document_capture_session).to receive(:passport_status).and_return('requested')
      end

      it 'returns expected local attributes' do
        expect(
          subject.locals_attrs(analytics:, presenter:, form_submit_url:),
        ).to include(
          presenter:,
          form_submit_url:,
          dos_passport_api_down: false,
          auto_check_value: :passport,
        )
      end
    end

    context 'when the dos passport api is not healthy' do
      before do
        allow(response).to receive(:success?).and_return(false)
      end

      it 'returns expected local attributes' do
        expect(
          subject.locals_attrs(analytics:, presenter:, form_submit_url:),
        ).to include(
          presenter:,
          form_submit_url:,
          dos_passport_api_down: true,
          auto_check_value: :drivers_license,
        )
      end
    end
  end
end
