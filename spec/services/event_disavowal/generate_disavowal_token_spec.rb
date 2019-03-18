require 'rails_helper'

describe EventDisavowal::GenerateDisavowalToken do
  describe '#call' do
    let(:event) { create(:event) }

    subject { described_class.new(event) }

    it 'adds a disavowal token fingerprint to an event and returns the token' do
      token = subject.call

      expect(Pii::Fingerprinter.fingerprint(token)).to eq(event.reload.disavowal_token_fingerprint)
    end
  end
end
