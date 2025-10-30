RSpec.shared_examples 'strong password' do |form_class|
  it 'does not allow a password that is common and/or needs more words' do
    user = build_stubbed(:user, email: 'test@test.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user: user)
    password = 'password foo'
    errors = {
      password: ['Your password is not strong enough.' \
        ' This is similar to a commonly used password.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }

    result = form.submit(
      password: password,
      password_confirmation: password,
    )

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'does not allow a password that needs more words' do
    user = build_stubbed(:user, email: 'test@test.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user: user)
    password = 'benevolentman'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }

    result = form.submit(
      password: password,
      password_confirmation: password,
    )

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'does not allow a password equal to a word from the user email' do
    user = build_stubbed(:user, email: 'janedoelongname@example.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user: user)
    password = 'janedoelongname'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }

    result = form.submit(
      password: password,
      password_confirmation: password,
    )

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'does not allow a password that is the user email' do
    user = build_stubbed(:user, email: 'custom@benevolent.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user: user)
    password = 'custom@benevolent.com'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }
    result = form.submit(
      password: password,
      password_confirmation: password,
    )

    expect(result.success?).to eq(false)
    expect(result.errors).to eq(errors)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end

  it 'it allows password with the minimum number of graphemes' do
    user = build_stubbed(:user, email: 'custom@example.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user: user)
    password = 'a7K!hf🇺🇸🇺🇸🇺🇸'
    result = form.submit(
      password: password,
      password_confirmation: password,
    )

    expect(result.success?).to eq(true)
    expect(result.extra).to include(user_id: '123') if result.extra.present?
  end
end
