# frozen_string_literal: true

# Monkey-patch Capybara::Node::Simple#visible? to consider a dialog element without an open
# attribute as hidden.
#
# >A `dialog` element without an `open` attribute specified should not be shown to the user.
#
# See: https://html.spec.whatwg.org/multipage/interactive-elements.html#attr-dialog-open
# See: https://github.com/teamcapybara/capybara/blob/master/lib/capybara/node/simple.rb

module Extensions
  Capybara::Node::Simple.class_eval do
    prepend(
      Module.new do
        def visible?(check_ancestors = true)
          if check_ancestors
            return false if find_xpath('boolean(./ancestor-or-self::dialog[not(@open)])')
          elsif tag_name == 'dialog' && native[:open].nil?
            return false
          end

          super(check_ancestors)
        end
      end,
    )
  end
end
