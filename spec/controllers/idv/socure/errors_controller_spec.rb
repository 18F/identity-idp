require 'rails_helper'

RSpec.describe Idv::Socure::ErrorsController do
  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_sign_in(user)
    subject.idv_session.socure_docv_wait_polling_started_at = Time.zone.now
  end

  describe '#show' do
    it 'logs an event' do
      get(:show)

      expect(@analytics).to have_logged_event(:idv_doc_auth_socure_error_visited)
    end

    it 'uses the transaction token from params' do
      transaction_token = 'test-transaction-token'

      get(:show, params: { transaction_token: transaction_token })

      expect(@analytics).to have_logged_event(
        :idv_doc_auth_socure_error_visited,
        hash_including(docv_transaction_token: transaction_token),
      )
    end
  end
end
