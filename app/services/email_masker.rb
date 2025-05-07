class EmailMasker
  attr_reader :email

  def initialize(email:)
    @email = email
  end

  def mask_email
    email.gsub(/^(.+)@(.+)$/) do |_match|
      local_part = $1
      domain_part = "@#{$2}"
      local_length = local_part.length
      mask_char = '*'

      masked_local_part = case local_length
                          when 1 then mask_char
                          when 2 then mask_char * 2
                          else
                            hidden_length = local_length - 2
                            local_part[0] + (mask_char * hidden_length) + local_part[-1]
                          end
      masked_local_part + domain_part
    end
  end
end