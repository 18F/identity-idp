require 'rails_helper'

describe RecoveryCodeForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = create(:user)
        raw_code = RecoveryCodeGenerator.new(user).create

        form = RecoveryCodeForm.new(user, raw_code)
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'recovery code' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.recovery_code).to be_nil
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user, :signed_up, recovery_code: 'code')

        form = RecoveryCodeForm.new(user, 'foo')
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'recovery code' }

        expect(RecoveryCodeGenerator).to_not receive(:new)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.recovery_code).to_not be_nil
      end
    end
  end
end
