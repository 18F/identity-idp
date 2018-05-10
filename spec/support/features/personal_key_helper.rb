module PersonalKeyHelper
  def reset_password_and_sign_back_in(user, password = 'a really long password')
    fill_in t('forms.passwords.edit.labels.password'), with: password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in_credentials_and_submit(user.email, password)
  end

  def personal_key_from_pii(user, pii)
    profile = create(:profile, :active, :verified, user: user)
    pii_attrs = Pii::Attributes.new_from_hash(pii)
    personal_key = profile.encrypt_pii(pii_attrs, user.password)
    profile.save!

    personal_key
  end

  def trigger_reset_password_and_click_email_link(email)
    visit new_user_password_path
    fill_in 'Email', with: email
    click_button t('forms.buttons.continue')
    open_last_email
    click_email_link_matching(/reset_password_token/)
  end

  def scrape_personal_key
    new_personal_key_words = []
    page.all(:css, '[data-personal-key]').each do |node|
      new_personal_key_words << node.text
    end
    new_personal_key_words.join('-')
  end
end
