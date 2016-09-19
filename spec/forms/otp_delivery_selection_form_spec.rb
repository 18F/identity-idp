require 'rails_helper'

describe OtpDeliverySelectionForm do
  subject { OtpDeliverySelectionForm.new }

  it { is_expected.to validate_inclusion_of(:otp_method).in_array(%w(sms voice)) }

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true for success?' do
        result = subject.submit(otp_method: 'sms', resend: true)

        result_hash = {
          success?: true,
          delivery_method: 'sms',
          resend?: true,
          errors: []
        }

        expect(result).to eq result_hash
      end
    end

    context 'when the form is invalid' do
      it 'returns false for success? and includes errors' do
        result = subject.submit(otp_method: 'foo')

        result_hash = {
          success?: false,
          delivery_method: 'foo',
          resend?: nil,
          errors: subject.errors.full_messages
        }

        expect(result).to eq result_hash
      end
    end
  end
end
