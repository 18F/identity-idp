module NavigationHelper
  # rack_test doesn't support breakpoints for styling, and we hide/show different
  # navigation items based on those. To avoid failing because Capybara finds multiple
  # delete links or having to enable JS on a bunch of tests, this is a helper to find the
  # sidenav links.

  def find_sidenav_delete_account_link
    within_sidenav { find_link(t('account.links.delete_account'), href: account_delete_path) }
  end

  def find_sidenav_forget_browsers_link
    within_sidenav { find_link(t('account.navigation.forget_browsers')) }
  end

  def within_sidenav(&block)
    within('.sidenav', &block)
  end
end
