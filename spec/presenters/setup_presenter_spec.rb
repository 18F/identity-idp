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
    it 'shows true for remember device cookie true and remember device default true' do
      presenter = described_class.new(current_user: user,
                            user_fully_authenticated: true,
                            user_opted_remember_device_cookie: true,
                            remember_device_default: true)
      expect(presenter.remember_device_box_checked?).to be_truthy
    end

    it 'shows false for remember device cookie nil and remember device default true' do
      presenter = described_class.new(current_user: user,
                                      user_fully_authenticated: true,
                                      user_opted_remember_device_cookie: nil,
                                      remember_device_default: true)
      expect(presenter.remember_device_box_checked?).to be_truthy
    end

    it 'shows true for remember device cookie true and remember device default false' do
      presenter = described_class.new(current_user: user,
                                      user_fully_authenticated: true,
                                      user_opted_remember_device_cookie: true,
                                      remember_device_default: false)
      expect(presenter.remember_device_box_checked?).to be_truthy
    end

    it 'shows false for remember device cookie nil and remember device default false' do
      presenter = described_class.new(current_user: user,
                                      user_fully_authenticated: true,
                                      user_opted_remember_device_cookie: nil,
                                      remember_device_default: false)
      expect(presenter.remember_device_box_checked?).to be_falsey
    end
  end
end
