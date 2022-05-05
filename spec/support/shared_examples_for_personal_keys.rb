shared_examples_for 'personal key page' do
  include PersonalKeyHelper
  include JavascriptDriverHelper

  context 'informational text' do
    before do
      click_continue if javascript_enabled?
    end

    context 'modal content' do
      it 'displays the modal title' do
        expect(page).to have_content t('forms.personal_key.title')
      end

      it 'displays the modal instructions' do
        expect(page).to have_content t('forms.personal_key.instructions')
      end
    end
  end

  context 'with javascript enabled', js: true do
    before do
      page.driver.browser.execute_cdp(
        'Browser.grantPermissions',
        origin: page.server_url,
        permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'],
      )
    end

    after do
      page.driver.browser.execute_cdp('Browser.resetPermissions')
    end

    it 'allows a user to copy the code into the confirmation modal' do
      click_on t('components.clipboard_button.label')
      copied_text = page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])')

      expect(copied_text).to eq(scrape_personal_key)
    end

    it 'validates as case-insensitive, crockford-normalized, length-limited, dash-flexible' do
      code_segments = scrape_personal_key.split('-')

      # Include dash between some segments and not others
      code = code_segments[0..1].join('-') + code_segments[2..3].join

      # Randomize case
      code = code.chars.map { |c| (rand 2) == 0 ? c.downcase : c.upcase }.join

      # De-normalize Crockford encoding
      code = code.sub('1', 'l').sub('0', 'O')

      # Add extra characters
      code += 'abc123qwerty'

      click_acknowledge_personal_key
      page.find(':focus').fill_in with: code

      path_before_submit = current_path
      within('[role=dialog]') { click_on t('forms.buttons.continue') }
      expect(current_path).not_to eq path_before_submit
    end
  end
end
