require 'rails_helper'

RSpec.describe 'users/backup_code_setup/create.html.erb' do
  let(:number_of_codes) { 10 }

  before do
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
    stub_const('BackupCodeGenerator::NUMBER_OF_CODES', number_of_codes)
    @codes = BackupCodeGenerator.new(nil).send(:generate_new_codes)
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('forms.backup_code.title'))

    render
  end

  it 'displays download link with plain text content equal to the users backup codes' do
    render

    doc = Nokogiri::HTML(rendered)
    download_link = doc.at_css('a[download]')
    data_uri = Idv::DataUrlImage.new(download_link[:href])

    expect(rendered).to have_content(t('components.download_button.label'))
    expect(data_uri.content_type).to include('text/plain')
    expect(data_uri.read).to eq(@codes.join("\n"))
  end

  it 'displays alert for backup code usage' do
    render

    expect(rendered).to have_selector(
      '.usa-alert',
      text: t(
        'forms.backup_code.caution_codes',
        count: ReadableNumber.of(BackupCodeGenerator::NUMBER_OF_CODES),
      ),
    )
  end

  it 'displays save backup codes checkbox' do
    render

    expect(rendered).to have_selector('lg-validated-field')
    expect(rendered).to have_selector('input[type=checkbox]')
  end

  it 'contains form post to backup_code_continue_path' do
    render

    expect(rendered)
      .to have_xpath("//form[@action='#{backup_code_continue_path}']")
    expect(rendered)
      .to have_xpath("//form[@method='post']")
  end

  it 'has continue button' do
    render

    expect(rendered).to have_button t('forms.buttons.continue')
  end

  it 'displays all backup codes' do
    render

    expect(rendered).to have_css('code', count: number_of_codes)
  end

  context 'with odd number of generated backup codes' do
    let(:number_of_codes) { 5 }

    it 'displays all backup codes' do
      render

      expect(rendered).to have_css('code', count: number_of_codes)
    end
  end

  context 'during account creation' do
    before do
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(true)
    end

    it 'shows a link to cancel backup code creation and choose another mfa option' do
      render

      expect(rendered).to have_button t(
        'two_factor_authentication.choose_another_option',
      )
    end
  end
end
