require 'rails_helper'

RSpec.describe TwoFactorLoginOptionsForm do
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

        expect(subject.submit(selection: 'sms').to_h).to eq(
          success: true,
          errors: {},
          **extra,
        )
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

        expect(subject.submit(selection: 'foo').to_h).to include(
          success: false,
          errors:,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end
  end
end
