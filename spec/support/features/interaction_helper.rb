module InteractionHelper
  def click_spinner_button_and_wait(...)
    click_on(...)
    begin
      expect(page).to have_no_css('lg-spinner-button.spinner-button--spinner-active', wait: 10)
    rescue Selenium::WebDriver::Error::StaleElementReferenceError,
           Selenium::WebDriver::Error::UnknownError => e
      raise e if e.is_a?(Selenium::WebDriver::Error::UnknownError) &&
                 !e.message.include?('Node with given id does not belong to the document')
      # A stale element error can occur when attempting to wait for the spinner to disappear if the
      # context in which the button was clicked (e.g. a `within` block) itself disappears. This is
      # fine, since if the ancestor disappears, it can be assumed that the button is gone too.
      #
      # We sometimes see "UnknownError" with an error message that is similar to a
      # StaleElementReferenceError, but have not been able to resolve it and are ignoring it
      # for now.
    end
  end
end
