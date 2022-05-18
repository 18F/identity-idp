module Idv
  module Steps
    module Ipp
      class WelcomeStep < DocAuthBaseStep
        def call
          FormResponse.new(success: true, extra: { some_example_value: 'hiiiii' })
        end
      end
    end
  end
end
