require 'rails_helper'

describe Funnel::Registration::ConfirmEmail do
  subject { described_class }

  it 'sets the confirmed_at' do
    user = create(:user)
    user_id = user.id
    Funnel::Registration::Create.call(user_id)

    expect(funnel.confirmed_at).to be_nil

    subject.call(user_id)
    expect(funnel.confirmed_at).to be_present
  end

  def funnel
    RegistrationLog.all.first
  end
end
