require 'rails_helper'

describe EventDisavowal::ValidateDisavowedEvent do
  let(:event) { create(:event) }
  subject { described_class.new(event) }

  describe '#call' do
    let(:result) { subject.call }

    context 'the event is valid' do
      it 'returns a successful response' do
        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'the event is nil' do
      let(:event) { nil }

      it 'returns an unsuccessful response' do
        expect(result.success?).to eq(false)
        expect(result.errors[:event]).to include(t('event_disavowals.errors.event_not_found'))
      end
    end

    context 'the event is already disavowed' do
      let(:event) { create(:event, disavowed_at: 1.day.ago) }

      it 'returns an unsuccessful response' do
        expect(result.success?).to eq(false)
        expect(result.errors[:event]).to include(
          t('event_disavowals.errors.event_already_disavowed'),
        )
      end
    end

    context 'it has been more than 10 days since the event occured' do
      let(:event) { create(:event, created_at: 11.days.ago) }

      it 'returns an unsuccessful response' do
        expect(result.success?).to eq(false)
        expect(result.errors[:event]).to include(
          t('event_disavowals.errors.event_disavowal_expired'),
        )
      end
    end
  end
end
