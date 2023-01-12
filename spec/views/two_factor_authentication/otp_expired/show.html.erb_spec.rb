require 'rails_helper'

describe 'two_factor_authentication/otp_expired/show.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.otp_expired'))

    render
  end
end
