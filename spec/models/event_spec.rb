require 'rails_helper'

describe Event do
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    let(:event) { build_stubbed(:event) }

    it { is_expected.to validate_presence_of(:event_type) }

    it 'factory built event is valid' do
      expect(event).to be_valid
    end
  end

  it 'has a translation for every event type' do
    missing_translations = Event.event_types.keys.select do |event_type|
      translation = I18n.t("event_types.#{event_type}", raise: true)
      translation.empty?
    rescue I18n::MissingTranslationData
      true
    end
    expect(missing_translations).to be_empty
  end
end
