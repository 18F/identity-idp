require 'rails_helper'

describe Event do
  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    let(:event) { build_stubbed(:event) }

    it { is_expected.to validate_presence_of(:location) }
    it { is_expected.to validate_presence_of(:event_type) }

    it 'factory built event is valid' do
      expect(event).to be_valid
    end
  end

  describe '#pretty_user_agent' do
    let(:event) { build_stubbed(:event) }

    it 'returns <Broswer>/<OS> string' do
      user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
                   ' (KHTML, like Gecko) Chrome/52.0.2743.82 Safari/537.36'
      expect(Event.pretty_user_agent(user_agent)).to eq('Chrome/X11')
    end
  end

  describe '#event_type_to_s' do
    it 'converts all events types to strings' do
      Event.event_types.keys.each do |event_type|
        expect(Event.event_type_to_s(event_type)).to be_a(String)
      end
    end

    it 'fails for invalid event_types' do
      expect { Event.event_type_to_s(:foobar) }.to raise_error(RuntimeError)
    end
  end
end
