require 'rails_helper'

RSpec.describe Idv::Socure::ErrorsController do
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
end
