import $ from 'jquery';

// Removing element from DOM (on click containing appropriate data attribute)
const dismiss = '[data-dismiss="true"]';
$(document).on('click', dismiss, (e) => { $(e.target).parent().remove(); });
