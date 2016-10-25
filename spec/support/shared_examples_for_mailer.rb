shared_examples 'a system email' do
  it 'is from the default email' do
    expect(mail.from).to eq [Figaro.env.email_from]
    expect(mail[:from].display_names).to eq [Figaro.env.email_from]
  end
end
