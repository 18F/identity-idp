# frozen_string_literal: true

class EmailMasker
  def self.mask(email)
    email.gsub(/^(.+)@(.+)$/) do |_match|
      local_part = $1
      domain_part = "@#{$2}"
      local_length = local_part.length
      mask_chars = '**'

      masked_local_part = case local_length
                          when 1..2 then mask_chars
                          else
                            local_part[0] + mask_chars + local_part[-1]
                          end
      masked_local_part + domain_part
    end
  end
end
