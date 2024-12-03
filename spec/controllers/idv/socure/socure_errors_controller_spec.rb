require 'rails_helper'

RSpec.describe Idv::Socure::SocureErrorsController do
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)

    subject.idv_session.socure_docv_wait_polling_started_at = Time.zone.now
    stub_sign_in(user)
    stub_analytics
  end

  describe '#timeout' do
    it 'logs an event' do
      get(:timeout)

      expect(@analytics).to have_logged_event(:idv_doc_auth_socure_error_visited)
    end
  end

  describe '#go_in_person' do
    it 'redirects to the start of the in person path' do
      get(:go_in_person)

      expect(subject.idv_session.opted_in_to_in_person_proofing).to eq(true)
      expect(subject.idv_session.flow_path).to eq('standard')
      expect(subject.idv_session.skip_doc_auth_from_how_to_verify).to eq(true)
      expect(response).to redirect_to(idv_document_capture_url(step: :idv_doc_auth))
    end

    it 'logs an event' do
      get(:go_in_person)

      expect(@analytics).to have_logged_event(:idv_doc_auth_socure_choose_in_person)
    end
  end
end
