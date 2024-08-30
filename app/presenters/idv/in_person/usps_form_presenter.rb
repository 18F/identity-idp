# frozen_string_literal: true

class Idv::InPerson::UspsFormPresenter
  include FormHelper
  # Filtered list to remove territories that cause errors in the USPS API
  def usps_states_territories
    us_states_territories.reject { |_name, abbrev| %w[AA AE AP UM].include?(abbrev) }
  end
end
