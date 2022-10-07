require 'rails_helper'

describe Funnel::Registration::AddMfa do
  let(:analytics) { FakeAnalytics.new }
  subject { described_class }

  let(:user_id) do
    user = create(:user)
    user.id
  end
  let(:funnel) { RegistrationLog.all.first }

  it 'shows user is not fully registered with no mfa' do
    expect(funnel&.registered_at).to_not be_present
  end

  it 'shows user is fully registered after adding an mfa' do
    subject.call(user_id, 'phone', analytics)

    expect(funnel.registered_at).to be_present
  end
end
