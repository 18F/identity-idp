require 'rails_helper'

describe EventDisavowal::FindDisavowedEvent do
  describe '#call' do
    let(:disavowal_token) { '1234abcd' }

    subject { described_class.new(disavowal_token) }

    context 'an event exists' do
      it 'returns the event' do
        disavowed_event = create(
          :event,
          disavowal_token_fingerprint: Pii::Fingerprinter.fingerprint(disavowal_token),
        )

        event = subject.call

        expect(event).to eq(disavowed_event)
      end
    end

    context 'an event exists with a disavowal token fingerprinted with an old key' do
      it 'returns the event' do
        disavowed_event = create(
          :event,
          disavowal_token_fingerprint: Pii::Fingerprinter.fingerprint(disavowal_token),
        )
        rotate_hmac_key

        event = subject.call

        expect(event).to eq(disavowed_event)
      end
    end

    context 'an event does not exist' do
      it 'returns nil' do
        event = subject.call

        expect(event).to be_nil
      end
    end
  end
end
