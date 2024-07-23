require 'rails_helper'

RSpec.describe NewDeviceConcern, type: :controller do
  let(:test_class) do
    Class.new do
      include NewDeviceConcern

      attr_reader :current_user, :user_session, :cookies

      def initialize(current_user:, user_session:, cookies:)
        @current_user = current_user
        @user_session = user_session
        @cookies = cookies
      end
    end
  end

  let(:cookies) { {} }
  let(:current_user) { create(:user) }
  let(:user_session) { {} }
  let(:instance) { test_class.new(current_user:, user_session:, cookies:) }

  describe '#set_new_device_session' do
    context 'with new device' do
      it 'sets user session value to true' do
        instance.set_new_device_session(nil)

        expect(user_session[:new_device]).to eq(true)
      end

      context 'with explicitly false parameter value' do
        it 'sets user session value to the value provided' do
          instance.set_new_device_session(false)

          expect(user_session[:new_device]).to eq(false)
        end
      end
    end

    context 'with authenticated device' do
      let(:current_user) { create(:user, :with_authenticated_device) }
      let(:cookies) { { device: current_user.devices.last.cookie_uuid } }

      it 'sets user session value to false' do
        instance.set_new_device_session(nil)

        expect(user_session[:new_device]).to eq(false)
      end

      context 'with explicitly true parameter value' do
        it 'sets user session value to the value provided' do
          instance.set_new_device_session(true)

          expect(user_session[:new_device]).to eq(true)
        end
      end
    end
  end

  describe '#new_device?' do
    subject(:new_device?) { instance.new_device? }

    context 'session value is unassigned' do
      it { expect(new_device?).to eq(true) }
    end

    context 'session value is true' do
      let(:user_session) { { new_device: true } }

      it { expect(new_device?).to eq(true) }
    end

    context 'session value is false' do
      let(:user_session) { { new_device: false } }

      it { expect(new_device?).to eq(false) }
    end
  end
end
