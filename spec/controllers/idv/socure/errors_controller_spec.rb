require 'rails_helper'

RSpec.describe Idv::Socure::ErrorsController do
  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_sign_in(user)
    subject.idv_session.socure_docv_wait_polling_started_at = Time.zone.now
  end

  describe '#timeout' do
    it 'logs an event' do
      get(:timeout)

      expect(@analytics).to have_logged_event(:idv_doc_auth_socure_error_visited)
    end
  end
end
