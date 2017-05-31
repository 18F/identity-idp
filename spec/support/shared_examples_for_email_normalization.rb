shared_examples 'email normalization' do |email|
  it 'downcases and strips the email before validation' do
    old_email = email

    subject.valid?

    expect(subject.email).to eq old_email.downcase.strip
  end
end
