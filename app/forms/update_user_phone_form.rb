class UpdateUserPhoneForm
  include ActiveModel::Model
  include FormPhoneValidator

  attr_accessor :phone, :international_code
  attr_reader :user

  def persisted?
    true
  end

  def initialize(user)
    @user = user
    self.phone = @user.phone
    self.international_code = Phonelib.parse(phone).country || PhoneFormatter::DEFAULT_COUNTRY
  end

  def submit(params)
    self.phone = params[:phone]
    self.international_code = params[:international_code]

    check_phone_change

    FormResponse.new(success: valid?, errors: errors.messages)
  end

  def phone_changed?
    phone_changed == true
  end

  private

  attr_reader :phone_changed

  def check_phone_change
    formatted_phone = PhoneFormatter.new.format(phone, country_code: international_code)

    return unless formatted_phone != @user.phone

    @phone_changed = true
    self.phone = formatted_phone
  end
end
