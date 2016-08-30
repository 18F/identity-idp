shared_examples 'password validation' do
  it do
    is_expected.to validate_presence_of(:password).with_message("can't be blank")
  end

  it do
    is_expected.to validate_length_of(:password).
      is_at_least(Devise.password_length.first)
  end

  it do
    is_expected.to validate_length_of(:password).
      is_at_most(Devise.password_length.last)
  end

  it do
    is_expected.to allow_value('ValidPassword1!').for(:password)
  end

  it do
    is_expected.to allow_value('ValidPassword1').for(:password)
  end

  it do
    is_expected.to allow_value('validpassword1!').for(:password)
  end

  it do
    is_expected.to allow_value('VALIDPASSWORD1!').for(:password)
  end

  it do
    is_expected.to allow_value('ValidPASSWORD!').for(:password)
  end

  it do
    is_expected.to allow_value('bear bull bat baboon').for(:password)
  end
end
