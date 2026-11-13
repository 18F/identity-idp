require 'rails_helper'

RSpec.describe Idv::PhoneRequiredController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:nds_layout) { true }
  let(:phone_first_flow) { true }
  let(:completed_step) { :choose_id_type }

  before do
    stub_sign_in(user)
    stub_analytics
    allow(controller).to receive(:nds_layout?).and_return(nds_layout)
    subject.idv_session.phone_first_flow = phone_first_flow
    stub_up_to(completed_step, idv_session: subject.idv_session) if completed_step
  end

  describe '#show' do
    context 'in the NDS phone-first flow at hybrid handoff' do
      it 'renders and logs the visit' do
        get :show

        expect(response).to render_template(:show)
        expect(@analytics).to have_logged_event(:idv_phone_required_visited)
      end
    end

    context 'in the legacy flow' do
      let(:nds_layout) { false }
      let(:phone_first_flow) { false }

      it 'redirects to the current IdV step without logging the visit' do
        get :show

        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(idv_phone_required_url)
        expect(@analytics).not_to have_logged_event(:idv_phone_required_visited)
      end
    end

    context 'after opting out of the NDS layout mid phone-first flow' do
      let(:nds_layout) { false }

      it 'redirects to the current IdV step without logging the visit' do
        expect(subject.idv_session.phone_first_flow?).to eq(true)

        get :show

        expect(response).to redirect_to(idv_document_capture_url)
        expect(@analytics).not_to have_logged_event(:idv_phone_required_visited)
      end
    end

    context 'in the NDS layout outside the phone-first flow' do
      let(:phone_first_flow) { false }

      it 'redirects to the current IdV step without logging the visit' do
        get :show

        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(idv_phone_required_url)
        expect(@analytics).not_to have_logged_event(:idv_phone_required_visited)
      end
    end

    context 'before reaching hybrid handoff' do
      let(:completed_step) { nil }

      it 'redirects to the current IdV step without logging the visit' do
        get :show

        expect(response).to redirect_to(idv_welcome_url)
        expect(@analytics).not_to have_logged_event(:idv_phone_required_visited)
      end
    end

    context 'for a fully verified legacy user' do
      let(:user) { create(:user, :proofed) }
      let(:nds_layout) { false }
      let(:phone_first_flow) { false }

      it 'redirects to the already-verified page without logging the visit' do
        get :show

        expect(response).to redirect_to(idv_activated_url)
        expect(@analytics).not_to have_logged_event(:idv_phone_required_visited)
      end
    end
  end
end
