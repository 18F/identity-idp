require 'rails_helper'

describe PasswordForm, type: :model do
  subject { PasswordForm.new(build_stubbed(:user)) }

  it_behaves_like 'password validation'
  it_behaves_like 'strong password', 'PasswordForm'

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns true' do
        user = build_stubbed(:user)

        form = PasswordForm.new(user)

        password = 'valid password'

        extra = {
          user_id: user.uuid,
          request_id_present: false,
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns false' do
        user = build_stubbed(:user, uuid: '123')

        form = PasswordForm.new(user)

        password = 'invalid'

        errors = {
          password: ["is too short (minimum is #{Devise.password_length.first} characters)"],
        }

        extra = {
          user_id: '123',
          request_id_present: false,
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit(password: password)).to eq result
      end
    end

    context 'when the request_id is passed in the params' do
      it 'tracks that it is present' do
        user = build_stubbed(:user)
        form = PasswordForm.new(user)
        password = 'valid password'
        extra = {
          user_id: user.uuid,
          request_id_present: true,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(password: password, request_id: 'foo')).to eq result
      end
    end

    context 'when the request_id is not properly encoded' do
      it 'does not throw an exception' do
        user = build_stubbed(:user)
        form = PasswordForm.new(user)
        password = 'valid password'
        extra = {
          user_id: user.uuid,
          request_id_present: true,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(password: password, request_id: "\xFFbar\xF8")).to eq result
      end
    end
  end
end
