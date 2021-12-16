shared_examples_for 'personal key page' do
  include XPathHelper

  context 'informational text' do
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
      click_on t('links.copy')
      copied_text = page.evaluate_async_script('navigator.clipboard.readText().then(arguments[0])')

      code = page.all('[data-personal-key]').map(&:text).join('-')
      expect(copied_text).to eq(code)
    end
  end
end
