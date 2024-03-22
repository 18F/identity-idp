require 'rails_helper'

RSpec.describe Users::PivCacRecommendedController do
  before do
    user = build(:user)
    stub_sign_in_before_2fa(user)
    stub_analytics
  end

  context '#show' do
  end

  context '#confirm' do
  end

  context '#skip' do
  end
end
