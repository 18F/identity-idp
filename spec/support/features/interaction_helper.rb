module InteractionHelper
  def click_spinner_button_and_wait(...)
    click_on(...)
    sleep(1)
    begin
      expect(page).to have_no_css('lg-spinner-button.spinner-button--spinner-active', wait: 10)
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # A stale element error can occur when attempting to wait for the spinner to disappear if the
      # context in which the button was clicked (e.g. a `within` block) itself disappears. This is
      # fine, since if the ancestor disappears, it can be assumed that the button is gone too.
    end
  end
end
