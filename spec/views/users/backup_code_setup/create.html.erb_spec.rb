require 'rails_helper'

RSpec.describe 'users/backup_code_setup/create.html.erb' do
  let(:number_of_codes) { 10 }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
    allow(view).to receive(:in_account_creation_flow?).and_return(false)
    allow(view).to receive(:enabled_mfa_methods_count).and_return(0)
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

  it 'does not render the NDS form-page card in the default layout' do
    render

    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the NDS heading and intro' do
      render

      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.auth--form-page h1', text: t('nds.backup_codes.title'))
      expect(rendered).to have_selector(
        '.auth__intro-description',
        text: t('nds.backup_codes.info'),
      )
    end

    it 'renders every backup code in the two-column code grid' do
      render

      expect(rendered).to have_css('.card .card__code-grid .card__code-grid-col', count: 2)
      expect(rendered).to have_css('.card__code-grid code.card__value', count: number_of_codes)
      @codes.each do |code|
        expect(rendered).to have_css('code', text: RandomPhrase.format(code, separator: '-'))
      end
    end

    it 'renders copy, download and print tertiary actions under a divider' do
      render

      expect(rendered).to have_css('.card hr.divider')
      expect(rendered).to have_css(
        "lg-clipboard-button[clipboard-text='#{@codes.join(' ')}'] button.usa-button--tertiary",
        text: t('components.clipboard_button.label'),
      )
      expect(rendered).to have_css(
        "a.usa-button--tertiary[download='backup_codes.txt']",
        text: t('components.download_button.label'),
      )
      expect(rendered).to have_css(
        'lg-print-button button.usa-button--tertiary',
        text: t('components.print_button.label'),
      )
    end

    it 'renders the required acknowledgment checkbox in a card' do
      render

      expect(rendered).to have_css(
        '.card .checkbox input.checkbox__input[type=checkbox][required]' \
        '[name="backup_code_accepted_form[backup_code_notice_accepted]"]',
        visible: :all,
      )
      expect(rendered).to have_css(
        '.checkbox__label.checkbox__label--regular .checkbox__label-text',
        text: t('nds.backup_codes.acknowledgment'),
      )
    end

    it 'submits the acknowledgment form to the continue path with a gated primary button' do
      render

      expect(rendered).to have_css(
        "form[action='#{backup_code_continue_path}'][data-nds-submit-gate]",
      )
      expect(rendered).to have_css('form input[name=_method][value=patch]', visible: :all)
      expect(rendered).to have_css(
        '.auth__actions button.usa-button[type=submit]',
        text: t('forms.buttons.continue'),
      )
      expect(rendered).to_not have_content(t('nds.mfa.choose_another_method'))
    end

    context 'in the multi-MFA selection flow' do
      before do
        allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(true)
      end

      it 'renders a tertiary choose-another-method delete submit' do
        render

        expect(rendered).to have_css(".auth__actions form[action='#{backup_code_delete_path}']")
        expect(rendered).to have_css(
          '.auth__actions form input[name=_method][value=delete]',
          visible: :all,
        )
        expect(rendered).to have_css(
          '.auth__actions button.usa-button--tertiary',
          text: t('nds.mfa.choose_another_method'),
        )
      end
    end

    context 'during account creation' do
      before do
        allow(view).to receive(:in_account_creation_flow?).and_return(true)
      end

      it 'sets the account-creation header progress on the security step' do
        render

        progress = view.content_for(:nds_header_progress)
        expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
      end
    end
  end
end
