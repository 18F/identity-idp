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
    it 'shows true for cookie: true, default: true' do
      expect(rem_me_presenter(cookie: true, default: true).remember_device_box_checked?).to be_truthy
    end

    it 'shows false for cookie: nil, default: true' do
      expect(rem_me_presenter(cookie: nil, default: true).remember_device_box_checked?).to be_truthy
    end

    it 'shows true for cookie: true, default: false' do
      expect(rem_me_presenter(cookie: true, default: false).remember_device_box_checked?).to be_truthy
    end

    it 'shows false for cookie: nil, default: false' do
      expect(rem_me_presenter(cookie: nil, default: false).remember_device_box_checked?).to be_falsey
    end
  end

  def rem_me_presenter(cookie:, default:)
    described_class.new(current_user: user,
                        user_fully_authenticated: true,
                        user_opted_remember_device_cookie: cookie,
                        remember_device_default: default)
  end
end
