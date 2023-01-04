require 'rails_helper'

describe 'two_factor_authentication/sms_expired/show.html.erb' do
  let(:user) { create(:user, :signed_up) }

  before do
    @presenter = TwoFactorAuthCode::PersonalKeyPresenter.new
    @personal_key_form = PersonalKeyForm.new(user)
    allow(view).to receive(:current_user).and_return(user)
  end
end
