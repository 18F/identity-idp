require 'rails_helper'

RSpec.describe Test::IppController do
  describe 'GET index' do
    context 'when allow_ipp_enrollment_approval? is true' do
      it 'renders enrollments' do
        allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(true)

        stub_sign_in
        get :index

        expect(response.status).to eq 200
        expect(response).to_not be_redirect
        expect(subject).to render_template(:index)
      end
    end

    context 'when allow_ipp_enrollment_approval? is false' do
      it 'renders 404' do
        allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(false)

        stub_sign_in
        get :index

        expect(response.status).to eq 404
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe 'PUT update' do
    context 'when allow_ipp_enrollment_approval? is true and pending enrollment is found' do
      it 'updates the enrollment via a background job' do
        allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(true)
        create(
          :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
        )
        job = instance_double(GetUspsProofingResultsJob)
        allow(GetUspsProofingResultsJob).to receive(:new).and_return(job)
        allow(job).to receive(:send).and_return(true)

        stub_sign_in
        put :update, params: { enrollment: InPersonEnrollment.last.id.to_s }

        expect(response).to redirect_to test_ipp_url
        expect(job).to have_received(:send)
      end
    end

    context 'when allow_ipp_enrollment_approval? is true but enrollment is not found' do
      it 'redirects to ipp_test_url with flash error' do
        allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(true)

        stub_sign_in
        put :update, params: { enrollment: '1' }

        expect(response).to redirect_to test_ipp_url
        expect(flash[:error]).to eq 'Could not find pending IPP enrollment with ID 1'
      end
    end

    context 'when allow_ipp_enrollment_approval? is false' do
      it 'renders 404' do
        allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(false)

        stub_sign_in
        put :update

        expect(response.status).to eq 404
        expect(response).to render_template('pages/page_not_found')
      end
    end
  end
end
