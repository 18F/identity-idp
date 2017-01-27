shared_examples_for 'recovery code page' do
  context 'regenerating recovery code with `Get another code` button' do
    scenario 'displays a flash message and a new code' do
      old_code = @user.reload.recovery_code

      click_link t('users.recovery_code.get_another')

      expect(@user.reload.recovery_code).to_not eq old_code
      expect(page).to have_content t('notices.send_code.recovery_code')
    end
  end

  context 'informational text' do
    let(:accordion_selector) { generate_class_selector('accordion') }
    let(:content_selector) { generate_class_selector('accordion-content') }

    scenario 'it displays the recovery code info header' do
      expect(page).to have_content(t('users.recovery_code.help_text_header'))
    end

    context 'with javascript disabled' do
      scenario 'content is visible by default' do
        expect(page).to have_xpath("//#{accordion_selector}[@aria-expanded='true']")
        expect(page).to have_xpath("//#{content_selector}[@aria-hidden='false']")
        expect(page).to have_content(t('users.recovery_code.help_text'))
      end
    end

    context 'with javascript enabled', js: true do
      scenario 'content is hidden by default' do
        expect(page).to have_xpath("//#{accordion_selector}[@aria-expanded='false']")
        expect(page).not_to have_content(t('users.recovery_code.help_text'))

        page.find('.accordion-header').click
        expect(page).to have_xpath("//#{accordion_selector}[@aria-expanded='true']")
        expect(page).to have_content(t('users.recovery_code.help_text'))
      end
    end
  end
end

def generate_class_selector(klass)
  "*[contains(concat(' ', normalize-space(@class), ' '), ' #{klass} ')]"
end
