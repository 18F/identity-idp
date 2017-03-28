shared_examples_for 'recovery code page' do
  include XPathHelper

  it 'hides confirmation importance reminder text by default' do
    expect(page).to have_xpath(
      "//div[@id='recovery-code-reminder-alert'][@aria-hidden='true']", visible: false
    )
  end

  it 'contains correct confirmation importance reminder text' do
    expect(page).to have_content(t('users.recovery_code.reminder'))
  end

  context 'regenerating recovery code with `Get another code` button' do
    scenario 'displays a flash message and a new code' do
      old_code = @user.reload.recovery_code

      click_link t('users.recovery_code.get_another')

      expect(@user.reload.recovery_code).to_not eq old_code
      expect(page).to have_content t('notices.send_code.recovery_code')
    end
  end

  context 'informational text' do
    let(:accordion_control_selector) { generate_class_selector('accordion-header-control') }
    let(:content_selector) { generate_class_selector('accordion-content') }

    scenario 'it displays the recovery code info header' do
      expect(page).to have_content(t('users.recovery_code.help_text_header'))
    end

    context 'with javascript disabled' do
      scenario 'content is visible by default' do
        expect(page).to have_xpath("//#{accordion_control_selector}[@aria-expanded='true']")
        expect(page).to have_xpath("//#{content_selector}")
        expect(page).to have_content(t('users.recovery_code.help_text'))
      end
    end

    context 'modal content' do
      it 'displays the modal title' do
        expect(page).to have_content t('forms.recovery_code.title')
      end

      it 'displays the modal instructions' do
        expect(page).to have_content t('forms.recovery_code.instructions')
      end
    end
  end
end
