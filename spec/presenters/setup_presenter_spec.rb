require 'rails_helper'

describe SetupPresenter do
  let(:user) { create(:user) }
  let(:presenter) do
    described_class.new(current_user: user,
                        user_fully_authenticated: false,
                        user_opted_remember_device_cookie: true,
                        remember_device_default: true)
  end

  describe 'shows correct step indication' do
    context 'with signed in user adding additional method' do
      let(:user) { build(:user, :signed_up) }
      let(:presenter) do
        described_class.new(current_user: user,
                            user_fully_authenticated: true,
                            user_opted_remember_device_cookie: true,
                            remember_device_default: true)
      end

      it 'does not show step count' do
        expect(presenter.steps_visible?).to eq false
      end
    end

    context 'with user signing up who has not chosen first option' do
      it 'shows user is on step 3 of 4' do
        expect(presenter.step).to eq '3'
      end
    end

    context 'with user signing up who has chosen first option' do
      let(:user) { build(:user, :with_webauthn) }

      it 'shows user is on step 4 of 4' do
        expect(presenter.step).to eq '4'
      end
    end
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
    presenter = described_class.new(current_user: user,
                        user_fully_authenticated: true,
                        user_opted_remember_device_cookie: cookie,
                        remember_device_default: default)
    expect(presenter.remember_device_box_checked?).to eq(value)
  end
end
