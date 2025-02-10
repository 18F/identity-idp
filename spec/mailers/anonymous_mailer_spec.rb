require 'rails_helper'

RSpec.describe AnonymousMailer, type: :mailer do
  let(:email) { 'email@example.com' }
  let(:request_id) { SecureRandom.uuid }

  describe '#password_reset_missing_user' do
    subject(:mail) { AnonymousMailer.with(email:).password_reset_missing_user(request_id:) }

    it_behaves_like 'a system email', synchronous_only: true
  end
end
