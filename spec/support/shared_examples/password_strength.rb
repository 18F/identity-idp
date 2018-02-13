shared_examples 'strong password' do |form_class|
  before(:each) do
    allow(Figaro.env).to receive(:password_strength_enabled).and_return('true')
  end

  it 'does not allow a password that is common and/or needs more words' do
    user = build_stubbed(:user, email: 'test@test.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'custom!@'
    errors = {
      password: ['Your password is not strong enough.' \
        ' This is similar to a commonly used password.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }
    if form_class == 'PasswordForm'
      extra = {
        user_id: '123',
        request_id_present: false,
      }
    elsif form_class == 'ResetPasswordForm'
      extra = {
        user_id: '123',
        active_profile: false,
        confirmed: true,
      }
    end
    result = instance_double(FormResponse)

    if %w[PasswordForm ResetPasswordForm].include?(form_class)
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors, extra: extra).and_return(result)
    else
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
    end
    expect(form.submit(password: password)).to eq result
  end

  it 'does not allow a password that needs more words' do
    user = build_stubbed(:user, email: 'test@test.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'benevolent'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }
    if form_class == 'PasswordForm'
      extra = {
        user_id: '123',
        request_id_present: false,
      }
    elsif form_class == 'ResetPasswordForm'
      extra = {
        user_id: '123',
        active_profile: false,
        confirmed: true,
      }
    end
    result = instance_double(FormResponse)

    if %w[PasswordForm ResetPasswordForm].include?(form_class)
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors, extra: extra).and_return(result)
    else
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
    end
    expect(form.submit(password: password)).to eq result
  end

  it 'does not allow a password containing words from the user email' do
    user = build_stubbed(:user, email: 'joe@gmail.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'joe gmail'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }
    if form_class == 'PasswordForm'
      extra = {
        user_id: '123',
        request_id_present: false,
      }
    elsif form_class == 'ResetPasswordForm'
      extra = {
        user_id: '123',
        active_profile: false,
        confirmed: true,
      }
    end
    result = instance_double(FormResponse)

    if %w[PasswordForm ResetPasswordForm].include?(form_class)
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors, extra: extra).and_return(result)
    else
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
    end
    expect(form.submit(password: password)).to eq result
  end

  it 'does not allow a password that is the user email' do
    user = build_stubbed(:user, email: 'custom@benevolent.com', uuid: '123')
    allow(user).to receive(:reset_password_period_valid?).and_return(true)
    form = form_class.constantize.new(user)
    password = 'custom@benevolent.com'
    errors = {
      password: ['Your password is not strong enough.' \
        ' Add another word or two.' \
        ' Uncommon words are better'],
    }
    if form_class == 'PasswordForm'
      extra = {
        user_id: '123',
        request_id_present: false,
      }
    elsif form_class == 'ResetPasswordForm'
      extra = {
        user_id: '123',
        active_profile: false,
        confirmed: true,
      }
    end
    result = instance_double(FormResponse)

    if %w[PasswordForm ResetPasswordForm].include?(form_class)
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors, extra: extra).and_return(result)
    else
      expect(FormResponse).to receive(:new).
        with(success: false, errors: errors).and_return(result)
    end
    expect(form.submit(password: password)).to eq result
  end
end
