class RescueCodesController < ApplicationController
  before_action :confirm_two_factor_authenticated

  def new
    @codes = current_user.create_backup_codes
    @codes.map! { |code| RescueCodesController.format_code(code) }
    text_code = RescueCodesController.plain_text_codes(@codes, current_user.email)
    @download_data_url = 'data:,' + ERB::Util.url_encode(text_code)
  end

  def codes_downloaded
    current_user.update!(backup_codes_downloaded: true)
    redirect_to after_sign_in_path_for(current_user)
  end

  def self.format_code(code)
    code[0, 4] + '-' + code[4, 8]
  end

  def self.plain_text_codes(codes, account_name)
    result = \
      "Your login.gov resuce codes\n" \
      "===========================\n" \
      "\n" \
      "Account: #{account_name}\n" \
      "Created: #{DateTime.now.strftime('%B %d, %Y')}\n" \
      "\n"
    codes.each_with_index do |code, index|
      result += "#{index + 1} #{code}\n"
    end
    result
  end
end
