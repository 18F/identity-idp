shared_examples 'a system email' do
  it 'is from the default email' do
    expect(mail.from).to eq [Identity::Hostdata.settings.email_from]
    expect(mail[:from].display_names).to eq [Identity::Hostdata.settings.email_from_display_name]
  end
end

# expects there to be a let(:user) in scope
shared_examples 'an email that respects user email locale preference' do
  before do
    user.email_language = 'fr'
    user.save!
  end

  it 'is in the correct locale' do
    expect(mail.parts.first.body).to have_content(I18n.t('mailer.privacy_policy', locale: 'fr'))
  end
end
