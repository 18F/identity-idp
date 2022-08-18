shared_examples 'email validation' do
  it 'uses the valid_email gem with mx and ban_disposable options' do
    email_validator = subject._validators.values.flatten.
      detect { |v| v.instance_of?(EmailValidator) }

    expect(email_validator.options).
      to eq(mx_with_fallback: true, ban_disposable_email: true)
  end
end
