require 'rails_helper'

RSpec.describe AuthMethodsSession do
  let(:user_session) { {} }
  let(:auth_methods_session) { described_class.new(user_session:) }

  around do |example|
    freeze_time { example.run }
  end

  describe '#authenticate!' do
    let(:auth_method) { 'example' }
    subject(:result) { auth_methods_session.authenticate!(auth_method) }

    context 'no auth events' do
      it 'modifies auth events to include the new event' do
        expect { result }.to change { auth_methods_session.auth_events }.
          from([]).
          to([{ auth_method:, at: Time.zone.now }])
      end

      it 'returns the new array of auth events' do
        expect(result).to eq([{ auth_method:, at: Time.zone.now }])
      end
    end

    context 'with existing auth event' do
      let(:first_auth_event) { { auth_method: 'first', at: Time.zone.now } }
      let(:user_session) { { auth_events: [first_auth_event] } }

      it 'appends the new event to the existing set' do
        expect { result }.to change { auth_methods_session.auth_events }.
          from([first_auth_event]).
          to([first_auth_event, { auth_method:, at: Time.zone.now }])
      end

      it 'returns the new array of auth events' do
        expect(result).to eq([first_auth_event, { auth_method:, at: Time.zone.now }])
      end
    end

    context 'with maximum tracked events' do
      before do
        stub_const('AuthMethodsSession::MAX_AUTH_EVENTS', 2)
      end

      let(:first_auth_event) { { auth_method: 'first', at: 2.days.ago } }
      let(:second_auth_event) { { auth_method: 'second', at: 1.day.ago } }
      let(:user_session) { { auth_events: [first_auth_event, second_auth_event] } }

      it 'ejects the oldest' do
        expect { result }.to change { auth_methods_session.auth_events }.
          from([first_auth_event, second_auth_event]).
          to([second_auth_event, { auth_method:, at: Time.zone.now }])
      end
    end
  end

  describe '#auth_events' do
    subject(:auth_events) { auth_methods_session.auth_events }

    context 'no auth events' do
      it 'returns an empty array' do
        expect(auth_events).to eq([])
      end
    end

    context 'with multiple auth events' do
      let(:session_auth_events) do
        [
          { auth_method: 'first', at: Time.zone.now },
          { auth_method: 'second', at: Time.zone.now },
        ]
      end
      let(:user_session) { { auth_events: session_auth_events } }

      it 'returns an array of auth events' do
        expect(auth_events).to eq(session_auth_events)
      end
    end
  end

  describe '#last_auth_event' do
    subject(:last_auth_event) { auth_methods_session.last_auth_event }

    context 'no auth events' do
      it { expect(last_auth_event).to be_nil }
    end

    context 'with multiple auth events' do
      let(:second_auth_event) { { auth_method: 'second', at: Time.zone.now } }
      let(:session_auth_events) do
        [
          { auth_method: 'first', at: 3.minutes.ago },
          second_auth_event,
        ]
      end
      let(:user_session) { { auth_events: session_auth_events } }

      it 'returns the last auth event' do
        expect(last_auth_event).to eq(second_auth_event)
      end
    end
  end

  describe '#recently_authenticated_2fa?' do
    subject(:recently_authenticated_2fa) { auth_methods_session.recently_authenticated_2fa? }

    context 'no auth events' do
      it { expect(recently_authenticated_2fa).to eq(false) }
    end

    context 'with remember device auth event' do
      let(:user_session) do
        {
          auth_events: [
            {
              auth_method: TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
              at: Time.zone.now,
            },
          ],
        }
      end

      it { expect(recently_authenticated_2fa).to eq(false) }

      context 'with non-remember device auth event' do
        let(:user_session) do
          {
            auth_events: [
              {
                auth_method: TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
                at: 3.minutes.ago,
              },
              {
                auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
                at: Time.zone.now,
              },
            ],
          }
        end

        it { expect(recently_authenticated_2fa).to eq(true) }
      end
    end

    context 'with non-remember device auth event' do
      let(:user_session) do
        {
          auth_events: [
            {
              auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
              at: Time.zone.now,
            },
          ],
        }
      end

      it { expect(recently_authenticated_2fa).to eq(true) }
    end
  end
end
