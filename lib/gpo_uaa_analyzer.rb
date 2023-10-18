class GpoUaaAnalyzer
  def doit
    data = []
    get_codes.each do |code|
      gpo_confirmation_code = GpoConfirmationCode.first_with_otp(code)
      profile = gpo_confirmation_code&.profile
      if profile.nil?
        data << "#{code}#{',missing' * 5}"
        next
      end
      data << [
        code,
        gpo_confirmation_code.created_at,
        profile.verified_at,
        which_letter(profile, gpo_confirmation_code),
        profile.gpo_confirmation_codes.length,
        profile.user.uuid,
      ].join(',')
    end
    data
  end

  def header
    %w[
      OTP
      created_at
      verified_at
      which_letter
      total_letters
      uuid
    ].join(',')
  end

  def writeit
    result = doit
    File.open('/tmp/foo.csv', 'w') do |f|
      f.write header + "\n"
      result.each do |line|
        f.write line + "\n"
      end
    end
  end

  def putsit
    puts header
    doit.each do |line|
      puts line
    end
  end

  def which_letter(profile, gpo_confirmation_code)
    profile.gpo_confirmation_codes.sort_by(&:code_sent_at).
      index(gpo_confirmation_code) + 1
  end

  def get_codes
    %w[

    ]
  end
end
