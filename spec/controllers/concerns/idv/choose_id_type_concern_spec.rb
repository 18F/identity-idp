require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeConcern, :controller do
  controller ApplicationController do
    include Idv::ChooseIdTypeConcern
  end

  subject { controller }

  let(:analytics) { FakeAnalytics.new }
  let(:step) { 'choose_id_type' }
  let(:context_analytics) { { step: step } }
  let(:passport_status) { nil }
  let(:document_capture_session) { create(:document_capture_session, passport_status:) }
  let(:id_type) { 'drivers_license' }
  let(:socure_docv_capture_app_url) { 'http://example.com' }
  let(:socure_docv_transaction_token) { '12345' }
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
    context 'when chosen_id_type is "passport"' do
      let(:id_type) { 'passport' }

      before do
        allow(controller).to receive(:params).and_return(parameters)
        subject.set_passport_requested
      end

      it 'updates the document_capture_session passport status to "requested"' do
        expect(document_capture_session.passport_requested?).to be true
      end

      it 'sets socure attributes to nil' do
        expect(document_capture_session.socure_docv_capture_app_url).to be_nil
        expect(document_capture_session.socure_docv_transaction_token).to be_nil
      end

      context 'passport was already requested' do
        let(:document_capture_session) do
          create(
            :document_capture_session,
            passport_status: 'requested',
            doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
            socure_docv_capture_app_url: socure_docv_capture_app_url,
            socure_docv_transaction_token: socure_docv_transaction_token,
          )
        end

        it 'keeps the socure attributes' do
          expect(document_capture_session.socure_docv_capture_app_url)
            .to eq(socure_docv_capture_app_url)
          expect(document_capture_session.socure_docv_transaction_token)
            .to eq(socure_docv_transaction_token)
        end
      end

      context 'when document_capture_session has has attributes from drivers license' do
        let(:document_capture_session) do
          create(
            :document_capture_session,
            passport_status: 'not_requested',
            doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
            socure_docv_capture_app_url: socure_docv_capture_app_url,
            socure_docv_transaction_token: socure_docv_transaction_token,
          )
        end

        it 'sets doc_auth_vendor to nil' do
          expect(document_capture_session.doc_auth_vendor).to be_nil
        end

        it 'resets socure attributes to nil' do
          expect(document_capture_session.socure_docv_capture_app_url).to be_nil
          expect(document_capture_session.socure_docv_transaction_token).to be_nil
        end
      end
    end

    context 'when chosen_id_type is not "passport"' do
      let(:id_type) { 'drivers_license' }

      before do
        allow(controller).to receive(:params).and_return(parameters)
        subject.set_passport_requested
      end

      it 'updates the document_capture_session passport status to "not_requested"' do
        expect(document_capture_session.passport_status).to eq('not_requested')
      end

      context 'when document_capture_session.passport_requested? is true' do
        let(:document_capture_session) do
          create(
            :document_capture_session,
            passport_status: 'requested',
            doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
            socure_docv_capture_app_url: socure_docv_capture_app_url,
            socure_docv_transaction_token: socure_docv_transaction_token,
          )
        end

        it 'sets socure attributes to nil' do
          expect(document_capture_session.socure_docv_capture_app_url).to be_nil
          expect(document_capture_session.socure_docv_transaction_token).to be_nil
        end
      end

      context 'when the document_capture_session doc_auth_vendor is already defined' do
        let(:document_capture_session) do
          create(
            :document_capture_session,
            passport_status:,
            doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
          )
        end

        it 'sets the doc_auth_vendor to nil' do
          expect(document_capture_session.doc_auth_vendor).to be_nil
        end
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
    it 'returns nil' do
      expect(subject.selected_id_type).to be_nil
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
  end

  describe '#dos_passport_api_healthy?' do
    context 'when the endpoint is set' do
      let(:response) { double(DocAuth::Dos::Responses::HealthCheckResponse) }
      let(:dos_passport_composite_healthcheck_endpoint) { 'http://dos-health.test/status' }

      before do
        allow(IdentityConfig.store).to receive(
          :dos_passport_composite_healthcheck_endpoint,
        ).and_return(dos_passport_composite_healthcheck_endpoint)
        allow(DocAuth::Dos::Requests::HealthCheckRequest).to receive(:new).and_call_original
        allow_any_instance_of(DocAuth::Dos::Requests::HealthCheckRequest).to receive(:fetch)
          .with(analytics, context_analytics: context_analytics).and_return(response)
      end

      context 'when the dos response is successful' do
        before do
          allow(response).to receive(:success?).and_return(true)
        end

        it 'returns true' do
          expect(subject.dos_passport_api_healthy?(analytics:, step:)).to be(true)
        end

        context 'when cached' do
          let(:dos_passport_composite_healthcheck_endpoint) { 'http://cached.dos-health.test/status' }

          before do
            allow(IdentityConfig.store)
              .to receive(:dos_passport_healthcheck_cache_expiration_seconds).and_return(5)
          end

          it 'uses cached value on repeat request' do
            expect(subject.dos_passport_api_healthy?(analytics:, step:)).to be(true)
            expect(subject.dos_passport_api_healthy?(analytics:, step:)).to be(true)
            expect(DocAuth::Dos::Requests::HealthCheckRequest).to have_received(:new).once
          end
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
      allow(request).to receive(:fetch).with(analytics, context_analytics: context_analytics)
        .and_return(response)
    end

    context 'when the dos passport api is healthy' do
      let(:passport_status) { 'requested' }

      before do
        allow(response).to receive(:success?).and_return(true)
      end

      it 'returns expected local attributes' do
        expect(
          subject.locals_attrs(presenter:, form_submit_url:),
        ).to include(
          presenter:,
          form_submit_url:,
          disable_passports: false,
          auto_check_value: :passport,
        )
      end
    end

    context 'when passports are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
          .and_return(false)
      end

      it 'returns expected local attributes with passports disabled' do
        expect(
          subject.locals_attrs(presenter:, form_submit_url:),
        ).to include(
          presenter:,
          form_submit_url:,
          disable_passports: true,
          auto_check_value: :drivers_license,
        )
      end
    end

    context 'when the dos passport api is not healthy' do
      before do
        parameters[:passports] = 'false'
        allow(controller).to receive(:params).and_return(parameters)
      end

      it 'returns expected local attributes' do
        expect(
          subject.locals_attrs(presenter:, form_submit_url:),
        ).to include(
          presenter:,
          form_submit_url:,
          disable_passports: true,
          auto_check_value: :drivers_license,
        )
      end
    end
  end
end
