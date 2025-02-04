require 'rails_helper'

RSpec.describe EventDisavowalController do
  let(:disavowal_token) { 'asdf1234' }
  let!(:event) do
    create(
      :event,
      disavowal_token_fingerprint: Pii::Fingerprinter.fingerprint(disavowal_token),
      created_at: Time.zone.now.change(usec: 0),
      device: create(:device, last_used_at: Time.zone.now.change(usec: 0)),
    )
  end

  before do
    stub_analytics
  end

  describe '#new' do
    context 'with a valid disavowal_token' do
      it 'tracks an analytics event' do
        get :new, params: { disavowal_token: disavowal_token }

        expect(@analytics).to have_logged_event(
          'Event disavowal visited',
          build_analytics_hash(user_id: event.user.uuid),
        )
      end

      it 'assigns forbidden passwords' do
        get :new, params: { disavowal_token: disavowal_token }

        expect(@analytics).to have_logged_event(
          'Event disavowal visited',
          build_analytics_hash(user_id: event.user.uuid),
        )
        expect(assigns(:forbidden_passwords)).to all(be_a(String))
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        get :new, params: { disavowal_token: disavowal_token }

        expect(@analytics).to have_logged_event(
          'Event disavowal token invalid',
          build_analytics_hash(
            user_id: event.user.uuid,
            success: false,
            error_details: { event: { event_already_disavowed: true } },
          ),
        )
      end

      it 'does not assign forbidden passwords' do
        event.update!(disavowed_at: Time.zone.now)

        get :new, params: { disavowal_token: disavowal_token }

        expect(@analytics).to have_logged_event(
          'Event disavowal token invalid',
          build_analytics_hash(
            user_id: event.user.uuid,
            success: false,
            error_details: { event: { event_already_disavowed: true } },
          ),
        )
        expect(assigns(:forbidden_passwords)).to be_nil
      end
    end
  end

  describe '#create' do
    context 'with a valid password' do
      it 'tracks an analytics event' do
        post :create, params: {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }

        expect(@analytics).to have_logged_event(
          'Event disavowal password reset',
          build_analytics_hash(user_id: event.user.uuid),
        )
      end
    end

    context 'with an invalid password' do
      it 'tracks an analytics event' do
        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'too short' },
        }

        post :create, params: params

        expect(@analytics).to have_logged_event(
          'Event disavowal password reset',
          build_analytics_hash(
            user_id: event.user.uuid,
            success: false,
            error_details: { password: { too_short: true } },
          ),
        )
      end

      it 'assigns forbidden passwords' do
        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'too short' },
        }

        post :create, params: params

        expect(@analytics).to have_logged_event(
          'Event disavowal password reset',
          build_analytics_hash(
            user_id: event.user.uuid,
            success: false,
            error_details: { password: { too_short: true } },
          ),
        )
        expect(assigns(:forbidden_passwords)).to all(be_a(String))
      end
    end

    context 'with an invalid disavowal_token' do
      it 'tracks an analytics event' do
        event.update!(disavowed_at: Time.zone.now)

        params = {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }

        post :create, params: params

        expect(@analytics).to have_logged_event(
          'Event disavowal token invalid',
          build_analytics_hash(
            user_id: event.user.uuid,
            success: false,
            error_details: { event: { event_already_disavowed: true } },
          ),
        )
      end
    end

    context 'with an event whose user has been deleted' do
      before do
        event.user.delete
      end

      it 'errors' do
        post :create, params: {
          disavowal_token: disavowal_token,
          event_disavowal_password_reset_from_disavowal_form: { password: 'salty pickles' },
        }

        expect(@analytics).to have_logged_event(
          'Event disavowal token invalid',
          build_analytics_hash(
            success: false,
            error_details: {
              user: { blank: true },
            },
          ),
        )
      end
    end
  end

  def build_analytics_hash(success: true, error_details: nil, user_id: nil)
    {
      event_created_at: event.created_at,
      disavowed_device_last_used_at: event.device&.last_used_at,
      success:,
      error_details:,
      event_id: event.id,
      event_type: event.event_type,
      event_ip: event.ip,
      disavowed_device_user_agent: event.device.user_agent,
      disavowed_device_last_ip: event.device.last_ip,
      user_id:,
    }.compact
  end
end
