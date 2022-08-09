require 'rails_helper'

describe Idv::Steps::WelcomeStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:params) { {} }
  let(:controller) do
    instance_double('controller', current_user: user, params: params, session: {}, url_options: {})
  end
  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = {}
    end
  end

  subject(:step) { Idv::Steps::WelcomeStep.new(flow) }

  describe '#call' do
    context 'without camera' do
      let(:params) { { no_camera: true } }

      it 'redirects to no camera error page' do
        result = step.call

        expect(redirect).to eq(idv_doc_auth_errors_no_camera_url)
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(
          message: 'Doc Auth error: Javascript could not detect camera on mobile device.',
        )
      end
    end

    context 'with previous establishing in-person enrollments' do
      let!(:enrollment) { create(:in_person_enrollment, :establishing, user: user, profile: nil) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      end

      it 'cancels all previous establishing enrollments' do
        step.call

        expect(enrollment.reload.status).to eq('cancelled')
        expect(user.establishing_in_person_enrollment).to be_blank
      end
    end
  end

  def redirect
    step.instance_variable_get(:@flow).instance_variable_get(:@redirect)
  end
end
