require 'rails_helper'

describe Funnel::Registration::AddPassword do
  subject { described_class }

  it 'sets the password_at' do
    user = create(:user)
    user_id = user.id
    Funnel::Registration::Create.call(user_id)

    expect(funnel.password_at).to be_nil

    subject.call(user_id)
    expect(funnel.password_at).to be_present
  end

  def funnel
    RegistrationLog.all.first
  end
end
