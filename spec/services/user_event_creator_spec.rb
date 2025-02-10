require 'rails_helper'

RSpec.describe UserEventCreator do
  let(:user_agent) { 'A computer on the internet' }
  let(:ip_address) { '4.4.4.4' }
  let(:existing_device_cookie) { 'existing_device_cookie' }
  let(:cookie_jar) do
    cookie_jar = ActionDispatch::Cookies::CookieJar.new(Rails.configuration.action_dispatch)
    cookie_jar.permanent[:device] = existing_device_cookie if existing_device_cookie
    cookie_jar
  end
  let(:request) do
    double(
      remote_ip: ip_address,
      user_agent: user_agent,
      cookie_jar: cookie_jar,
    )
  end
  let(:user) { create(:user, :fully_registered) }
  let(:device) { create(:device, user: user, cookie_uuid: existing_device_cookie) }
  let(:event_type) { 'account_created' }

  subject { UserEventCreator.new(request: request, current_user: user) }

  before do
    # Memoize user and device before specs run
    user
    device
  end

  describe '#create_user_event' do
    context 'when a device exists for the user' do
      it 'updates the device and creates an event' do
        event, _disavowal_token = subject.create_user_event(event_type, user)

        expect(event.event_type).to eq(event_type)
        expect(event.ip).to eq(ip_address)
        expect(event.device).to eq(device.reload)
        expect(device.last_ip).to eq(ip_address)
        expect(device.last_used_at).to be_within(1).of(Time.zone.now)
      end

      it 'refreshes the permanent cookie' do
        expect(cookie_jar.permanent).to receive(:[]=).with(:device, existing_device_cookie)

        subject.create_user_event(event_type, user)
      end
    end

    context 'when a device exists that is not associated with the user' do
      let(:device) { create(:device, cookie_uuid: existing_device_cookie) }

      it 'creates a device and creates an event' do
        expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:call)

        event, _disavowal_token = subject.create_user_event(event_type, user)

        expect(event.event_type).to eq(event_type)
        expect(event.ip).to eq(ip_address)
        expect(event.device.id).to_not eq(device.reload.id)
        expect(event.device.last_ip).to eq(ip_address)
        expect(event.device.last_used_at).to be_within(1).of(Time.zone.now)
      end
    end

    context 'when no device exists' do
      let(:device) { nil }

      it 'creates a device and creates an event' do
        expect(UserAlerts::AlertUserAboutNewDevice).to_not receive(:call)

        event, _disavowal_token = subject.create_user_event(event_type, user)

        expect(event.event_type).to eq(event_type)
        expect(event.ip).to eq(ip_address)
        expect(event.device.last_ip).to eq(ip_address)
        expect(event.device.last_used_at).to be_within(1).of(Time.zone.now)
      end

      context 'when there is no device cookie' do
        let(:existing_device_cookie) { nil }

        it 'assigns one to the device' do
          event, _disavowal_token = subject.create_user_event(event_type, user)

          expect(event.device.cookie_uuid.length).to eq(UserEventCreator::COOKIE_LENGTH)
        end

        it 'saves the cookie permanently' do
          expect { subject.create_user_event(event_type, user) }.to change { cookie_jar[:device] }
            .from(nil)
            .to(lambda { |value| value == Device.last.cookie_uuid })
        end
      end
    end
  end

  describe '#create_user_event_with_disavowal' do
    it 'creates a device with a disavowal' do
      event, disavowal_token = subject.create_user_event_with_disavowal(event_type, user)

      expect(event.disavowal_token_fingerprint)
        .to eq(Pii::Fingerprinter.fingerprint(disavowal_token))
    end
  end

  describe '#create_out_of_band_user_event' do
    let(:request) { nil }
    let(:event_type) { :password_invalidated }

    it 'creates an event without a device and without an IP address' do
      event, _disavowal_token = subject.create_out_of_band_user_event(event_type)

      expect(event.event_type).to eq(event_type.to_s)
      expect(event.ip).to be_blank
      expect(event.device).to be_blank
    end
  end
end
