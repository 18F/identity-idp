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
          'Event disavowal visited',
          build_analytics_hash,
        )

        get :new, params: { disavowal_token: disavowal_token }
      end

      it 'assigns forbidden passwords' do
        expect(@analytics).to receive(:track_event).with(
          'Event disavowal visited',
          build_analytics_hash,
        )

        get :new, params: { disavowal_token: disavowal_token }

        expect(assigns(:forbidden_passwords)).to all(be_a(String))
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        expect(@analytics).to receive(:track_event).with(
          'Event disavowal token invalid',
          build_analytics_hash(
            success: false,
            errors: { event: [t('event_disavowals.errors.event_already_disavowed')] },
          ),
        )

        get :new, params: { disavowal_token: disavowal_token }
      end

      it 'does not assign forbidden passwords' do
        event.update!(disavowed_at: Time.zone.now)

        expect(@analytics).to receive(:track_event).with(
          'Event disavowal token invalid',
          build_analytics_hash(
            success: false,
            errors: { event: [t('event_disavowals.errors.event_already_disavowed')] },
          ),
        )

        get :new, params: { disavowal_token: disavowal_token }

        expect(assigns(:forbidden_passwords)).to be_nil
      end
    end
  end

  describe '#create' do
    context 'with a valid password' do
      it 'tracks an analytics event' do
        expect(@analytics).to receive(:track_event).with(
          'Event disavowal password reset',
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
          'Event disavowal password reset',
          build_analytics_hash(
            success: false,
            errors: { password: ['This password is too short (minimum is 12 characters)'] },
          ),
        )

        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'too short' },
        }

        post :create, params: params
      end

      it 'assigns forbidden passwords' do
        expect(@analytics).to receive(:track_event).with(
          'Event disavowal password reset',
          build_analytics_hash(
            success: false,
            errors: { password: ['This password is too short (minimum is 12 characters)'] },
          ),
        )

        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'too short' },
        }

        post :create, params: params

        expect(assigns(:forbidden_passwords)).to all(be_a(String))
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        expect(@analytics).to receive(:track_event).with(
          'Event disavowal token invalid',
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

    context 'with an event whose user has been deleted' do
      before do
        event.user.delete
      end

      it 'errors' do
        expect(@analytics).to receive(:track_event).with(
          'Event disavowal token invalid',
          build_analytics_hash(
            success: false,
            errors: {
              user: [t('event_disavowals.errors.no_account')],
            },
          ),
        )

        post :create, params: {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }
      end
    end
  end

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
