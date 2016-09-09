shared_examples 'email validation' do
  it 'uses the valid_email gem with mx and ban_disposable options' do
    email_validator = subject._validators.values.flatten.
                      detect { |v| v.class == EmailValidator }

    expect(email_validator.options).
      to eq(mx: true, ban_disposable_email: true)
  end

  describe '#submit' do
    context 'when email is already taken' do
      it 'returns true to prevent revealing account existence' do
        create(:user, :signed_up, email: 'taken@gmail.com')

        result = subject.submit(email: 'TAKEN@gmail.com')

        expect(result).to be true
        expect(subject.email).to eq 'taken@gmail.com'
      end
    end

    context 'when email is not already taken' do
      it 'is valid' do
        result = subject.submit(email: 'not_taken@gmail.com')

        expect(result).to be true
      end
    end

    context 'when email is invalid' do
      it 'returns false and adds errors to the form object' do
        result = subject.submit(email: 'invalid_email')

        expect(result).to be false
        expect(subject.errors[:email]).
          to eq [t('valid_email.validations.email.invalid')]
      end
    end
  end
end
