module DocPiiHelper
  def pii_like_keypaths
    [
      [:pii],
      [:name, :dob, :dob_min_age, :address1, :state, :zipcode, :jurisdiction],
      [:errors, :name], [:error_details, :name],
      [:errors, :dob], [:error_details, :dob],
      [:errors, :dob_min_age], [:error_details, :dob_min_age],
      [:errors, :address1], [:error_details, :address1],
      [:errors, :state], [:error_details, :state],
      [:errors, :zipcode], [:error_details, :zipcode],
      [:errors, :jurisdiction], [:error_details, :jurisdiction]
    ]
  end
end
