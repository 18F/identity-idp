require 'rails_helper'

RSpec.describe EventDecorator do
  let(:event) { build_stubbed(:event, event_type: :email_changed) }
  subject(:decorator) { EventDecorator.new(event) }

  describe '#event_type' do
    it 'returns the localized event_type' do
      expect(decorator.event_type).to eq t('event_types.email_changed')
    end

    context 'for an event type that interpolates the app name' do
      let(:event) { build_stubbed(:event, event_type: :password_invalidated) }

      it 'returns the localized event_type' do
        expect(decorator.event_type).to eq t('event_types.password_invalidated', app_name: APP_NAME)
        expect(decorator.event_type).to include(APP_NAME)
      end
    end
  end

  describe '#last_sign_in_location_and_ip' do
    let(:event) { build_stubbed(:event, event_type: :password_invalidated, ip: ip_address) }

    context 'with an ip address' do
      let(:ip_address) { '0.0.0.0' }

      it 'is an approximate location' do
        expect(decorator.last_sign_in_location_and_ip).
          to eq('From 0.0.0.0 (IP address potentially located in United States)')
      end
    end

    context 'with a blank ip address' do
      let(:ip_address) { nil }

      it 'is empty' do
        expect(decorator.last_sign_in_location_and_ip).to eq('')
      end
    end
  end

  describe '#last_location' do
    let(:event) { build_stubbed(:event, event_type: :password_invalidated, ip: ip_address) }

    context 'with an ip address' do
      let(:ip_address) { '0.0.0.0' }

      it 'is the location' do
        expect(decorator.last_location).to eq('United States')
      end
    end

    context 'with a blank ip address' do
      let(:ip_address) { nil }

      it 'is empty' do
        expect(decorator.last_location).to eq('')
      end
    end
  end
end
