require 'rails_helper'

RSpec.describe SetupPresenter do
  let(:user) { create(:user) }
  let(:presenter) do
    described_class.new(
      current_user: user,
      user_fully_authenticated: false,
      user_opted_remember_device_cookie: true,
      remember_device_default: true,
    )
  end

  describe 'shows correct value for remember device' do
    it 'shows true for cookie: true, default value: true' do
      expect_remember_me_value_to_be(cookie: true, default: true, value: true)
    end

    it 'shows false for cookie: nil, default value: true' do
      expect_remember_me_value_to_be(cookie: nil, default: true, value: true)
    end

    it 'shows true for cookie: true, default value: false' do
      expect_remember_me_value_to_be(cookie: true, default: false, value: true)
    end

    it 'shows false for cookie: nil, default value: false' do
      expect_remember_me_value_to_be(cookie: nil, default: false, value: false)
    end
  end

  def expect_remember_me_value_to_be(cookie:, default:, value:)
    presenter = described_class.new(
      current_user: user,
      user_fully_authenticated: true,
      user_opted_remember_device_cookie: cookie,
      remember_device_default: default,
    )
    expect(presenter.remember_device_box_checked?).to eq(value)
  end
end
