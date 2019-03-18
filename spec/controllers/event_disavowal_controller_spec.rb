require 'rails_helper'

describe EventDisavowalController do
  let(:disavowal_token) { 'asdf1234' }
  let(:event) do
    create(
      :event,
      disavowal_token_fingerprint: Pii::Fingerprinter.fingerprint(disavowal_token),
    )
  end

  before do
    stub_analytics
  end

  describe '#new' do
    context 'with a valid disavowal_token' do
      it 'tracks an analytics event' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::EVENT_DISAVOWAL,
          build_analytics_hash,
        )

        get :new, params: { disavowal_token: disavowal_token }
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        expect(@analytics).to receive(:track_event).with(
          Analytics::EVENT_DISAVOWAL_TOKEN_INVALID,
          build_analytics_hash(
            success: false,
            errors: { event: [t('event_disavowals.errors.event_already_disavowed')] },
          ),
        )

        get :new, params: { disavowal_token: disavowal_token }
      end
    end
  end

  describe '#create' do
    context 'with a valid passowrd' do
      it 'tracks an analytics event' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::EVENT_DISAVOWAL_PASSWORD_RESET,
          build_analytics_hash,
        )

        post :create, params: {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }
      end
    end

    context 'with an invalid password' do
      it 'tracks an analytics event' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::EVENT_DISAVOWAL_PASSWORD_RESET,
          build_analytics_hash(
            success: false,
            errors: { password: ['is too short (minimum is 12 characters)'] },
          ),
        )

        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'too short' },
        }

        post :create, params: params
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        expect(@analytics).to receive(:track_event).with(
          Analytics::EVENT_DISAVOWAL_TOKEN_INVALID,
          build_analytics_hash(
            success: false,
            errors: { event: [t('event_disavowals.errors.event_already_disavowed')] },
          ),
        )

        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }

        post :create, params: params
      end
    end
  end

  # :reek:BooleanParameter
  def build_analytics_hash(success: true, errors: {})
    hash_including(
      :event_created_at,
      :disavowed_device_last_used_at,
      success: success,
      errors: errors,
      event_id: event.id,
      event_type: event.event_type,
      event_ip: event.ip,
      disavowed_device_user_agent: event.device.user_agent,
      disavowed_device_last_ip: event.device.last_ip,
    )
  end
end
