require 'rails_helper'

describe PersonalKeyForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = create(:user)
        raw_code = PersonalKeyGenerator.new(user).create
        old_key = user.reload.personal_key

        form = PersonalKeyForm.new(user, raw_code)
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.personal_key).to eq old_key
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = create(:user, :signed_up, personal_key: 'code')
        errors = { personal_key: ['Incorrect personal key'] }

        form = PersonalKeyForm.new(user, 'foo')
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.personal_key).to_not be_nil
        expect(form.personal_key).to be_nil
      end
    end
  end
end
