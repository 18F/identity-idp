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
end
