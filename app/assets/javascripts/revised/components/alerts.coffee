class BikeIndex.Alerts extends BikeIndex
  constructor: ->
    @fadeOutAlerts()
    @displayStoredAlerts()

  add: (alert_type = 'error', alert_body = '', callback = false) ->
    if callback # The only reason to pass a callback is if it will reload the page
      @storeAlert(alert_type, alert_body, callback) # So store the alert and run the callback
    else
      @displayAlert(alert_type, alert_body)

  displayAlert: (alert_type, alert_body, seconds = 7) ->
    $('.primary-alert-block').removeClass('faded')
    template = $('#alert-template').html()
    # Mustache.parse(template) # Unsure if this is useful if we call it every time?
    attrs =
      alert_type: alert_type
      alert_body: alert_body
      seconds: seconds
    $('.primary-alert-block').append(Mustache.render(template, attrs))
    @fadeOutAlerts()

  fadeOutAlerts: ->
    for alert in $('.primary-alert-block .in')
      $alert = $(alert)
      # Set seconds to 0 to display forever
      if $alert.data('seconds') > 0
        $alert.removeClass('in')
        @fadeAlert($alert, $alert.attr('data-seconds'))

  fadeAlert: ($alert, seconds) ->
    setTimeout (->
      $alert.fadeOut 'slow', ->
        $alert.slideUp 'fast', ->
          # To reduce the number of divs that have fixed positioning
          $alert.remove() # Remove the alert so we can check if there are any alerts
          unless $('.primary-alert-block .alert').length > 0
            $('.primary-alert-block').addClass('faded')
    ), seconds*1000

  storeAlert: (alert_type, alert_body, callback) ->
    # Store the alert and then run the callback (that we assume reloads the page)
    stored_alert = 
      alert_type: alert_type
      alert_body: alert_body
    localStorage.setItem('stored_alert', JSON.stringify(stored_alert))
    callback()

  displayStoredAlerts: ->
    stored_alert = localStorage.getItem 'stored_alert'
    if stored_alert
      alert = JSON.parse stored_alert
      @displayAlert(alert.alert_type, alert.alert_body)
      localStorage.removeItem 'stored_alert'


    