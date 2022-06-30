module InteractionHelper
  def click_spinner_button(...)
    click_button(...)
    expect(page).to have_no_css('lg-spinner-button.spinner-button--spinner-active', wait: 10)
  end
end
