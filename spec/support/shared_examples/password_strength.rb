RSpec.shared_examples 'strong password' do |form_class|
  it 'does not allow a password that has been added to database of compromised passwords' do
    user = build_stubbed(:user, email: 'test@test.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = '3.141592653589'
    errors = {
      password: ['The password you entered is not safe. It’s in a list of' \
        ' known passwords exposed in data breaches.'],
    }

    result = form.submit(password: password)

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'does not allow a password that is the user email' do
    user = build_stubbed(:user, email: 'custom@benevolent.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'custom@benevolent.com'
    errors = {
      password: ['Avoid using phrases that are easily guessed, such as' \
        ' parts of your email or personal dates.'],
    }
    result = form.submit(password: password)

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'does not allow a password that does not have the minimum number of graphemes' do
    user = build_stubbed(:user, email: 'custom@example.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'a7K!hf🇺🇸🇺🇸🇺🇸'
    errors = {
      password: [t('errors.attributes.password.too_short', count: 12)],
    }
    result = form.submit(password: password)

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end
end
