include FormHelper

class Idv::InPerson::UspsStatesTerritoriesPresenter
  # Filtered list to remove territories that cause errors in the USPS API
  def usps_states_territories
    FormHelper.us_states_territories.reject { |_name, abbrev| %w[AA AE AP UM].include?(abbrev) }
  end
end
