module DocPiiHelper
  def pii_like_keypaths
    [
      [:pii],
      [:errors, :name],
      [:error_details, :name],
      [:error_details, :name, :name],
      [:errors, :dob],
      [:error_details, :dob],
      [:error_details, :dob, :dob],
      [:errors, :dob_min_age],
      [:error_details, :dob_min_age],
      [:error_details, :dob_min_age, :dob_min_age],
      [:errors, :address1],
      [:error_details, :address1],
      [:error_details, :address1, :address1],
      [:errors, :state],
      [:error_details, :state],
      [:error_details, :state, :state],
      [:errors, :zipcode],
      [:error_details, :zipcode],
      [:error_details, :zipcode, :zipcode],
      [:errors, :jurisdiction],
      [:error_details, :jurisdiction],
      [:error_details, :jurisdiction, :jurisdiction],
      [:errors, :state_id_number],
      [:error_details, :state_id_number],
      [:error_details, :state_id_number, :state_id_number],
    ]
  end
end
