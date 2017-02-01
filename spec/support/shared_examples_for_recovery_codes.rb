shared_examples_for 'recovery code page' do
  it 'hides confirmation importance reminder text by default' do
    expect(page).to have_xpath(
      "//div[@id='recovery-code-reminder'][@aria-hidden='true']", visible: false
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

    context 'modal content' do
      it 'displays the modal title' do
        expect(page).to have_content t('forms.recovery_code.title')
      end

      it 'displays the modal instructions' do
        expect(page).to have_content t('forms.recovery_code.instructions')
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

      scenario 'modal opens when continue is clicked', js: true do
        expect(page).to have_xpath("//div[@id='personal-key-confirm'][@class='hide']")

        click_acknowledge_recovery_code

        expect(page).not_to have_xpath("//div[@id='personal-key-confirm'][@class='hide']")
      end

      context 'closing the modal', js: true do
        before do
          click_acknowledge_recovery_code
          click_on t('forms.buttons.back')
        end

        scenario 'modal closes when back button within modal is clicked' do
          expect(page).to have_xpath("//div[@id='personal-key-confirm'][@class='hide']")
        end

        scenario 'warning alert message appears' do
          expect(page).to have_xpath(
            "//div[@id='recovery-code-reminder'][@aria-hidden='false']"
          )
        end
      end
      context 'submitting the confirmation form' do
        scenario 'does not submit when invalid' do
          click_acknowledge_recovery_code
          click_on t('forms.buttons.continue'), class: 'recovery-code-confirm'
          expect(current_path).not_to eq profile_path
        end

        scenario 'submits when valid' do
          acknowledge_and_confirm_recovery_code
          expect(page).to have_current_path profile_path
        end
      end
    end
  end
end
