shared_examples_for 'personal key page' do
  include XPathHelper

  context 'regenerating personal key with `Get another code` button' do
    scenario 'displays a flash message and a new code' do
      old_code = @user.reload.personal_key

      click_button t('users.personal_key.get_another')

      expect(@user.reload.personal_key).to_not eq old_code
      expect(page).to have_content t('notices.send_code.personal_key')
    end
  end

  context 'informational text' do
    let(:accordion_control_selector) { generate_class_selector('accordion-header-controls') }
    let(:content_selector) { generate_class_selector('accordion-content') }

    scenario 'it displays the personal key info header' do
      expect(page).to have_content(t('users.personal_key.help_text_header'))
    end

    context 'with javascript disabled' do
      scenario 'content is visible by default' do
        expect(page).to have_xpath("//#{accordion_control_selector}[@aria-expanded='true']")
        expect(page).to have_xpath("//#{content_selector}")
        expect(page).to have_content(t('users.personal_key.help_text'))
      end
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
end
