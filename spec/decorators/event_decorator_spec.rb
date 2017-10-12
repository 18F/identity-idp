require 'rails_helper'

describe EventDecorator do
  describe '#event_type' do
    it 'returns the localized event_type' do
      event = build_stubbed(:event, event_type: :email_changed)
      decorator = EventDecorator.new(event)

      expect(decorator.event_type).to eq t('event_types.email_changed')
    end
  end
end
