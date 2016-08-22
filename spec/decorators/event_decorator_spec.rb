require 'rails_helper'

describe EventDecorator do
  describe '#pretty_event_type' do
    it 'returns the localized text corresponding to the event type' do
      event = build_stubbed(:event, event_type: :email_changed)
      decorator = EventDecorator.new(event)

      expect(decorator.pretty_event_type).to eq t('event_types.email_changed')
    end
  end
end
