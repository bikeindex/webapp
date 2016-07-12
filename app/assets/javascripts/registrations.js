// 
// require self
//= require jquery2
//= require jquery_ujs
//= require bootstrap
//= require selectize/standalone/selectize.js
//= require external_scripts/selectize_placeholder_plugin.js
//= require revised/components/manufacturers_select.js

$(document).ready(function() {
  // Load the fancy selects
  $('.unfancy.fancy-select select').selectize({
    create: false,
    plugins: ['restore_on_backspace']
  });
  // Load the manufacturers select
  new window.ManufacturersSelect('#binx_registration_widget #b_param_manufacturer_id');
});
