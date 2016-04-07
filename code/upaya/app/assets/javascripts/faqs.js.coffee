# see https://github.com/18F/save-ferris/issues/316 for `ready = ->` explanation
ready = ->
  $('li.faq a.question').click ->
    $(this).parent().next().toggle()
    aria_expanded = $(this).attr('aria-expanded')
    if aria_expanded == 'false'
      $(this).attr('aria-expanded', 'true')
      $(this).parent().next().focus()
      $(this).find("span").html("Select to hide answer")
    if aria_expanded == 'true'
      $(this).attr('aria-expanded', 'false')
      $(this).find("span").html("Select to show answer")
    return false

$(document).ready(ready)
$(document).on('page:load', ready)