require 'rails_helper'

describe TwoFactorLoginOptionsForm do
  subject do
    TwoFactorLoginOptionsForm.new(
      build_stubbed(:user),
    )
  end

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true for success?' do
        extra = {
          selection: 'sms',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(selection: 'sms')).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns false for success? and includes errors' do
        errors = {
          selection: ['is not included in the list'],
        }

        extra = {
          selection: 'foo',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit(selection: 'foo')).to eq result
      end
    end
  end
end
