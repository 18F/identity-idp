require 'rails_helper'

RSpec.describe TwoFactorAuthCode::SmsOptInPresenter do
  subject(:presenter) { TwoFactorAuthCode::SmsOptInPresenter.new }

  describe '#redirect_location_step' do
    subject(:redirect_location_step) { presenter.redirect_location_step }

    it { expect(redirect_location_step).to be_present }
  end
end
