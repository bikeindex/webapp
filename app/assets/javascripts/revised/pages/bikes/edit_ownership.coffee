class BikeIndex.BikesEditOwnership extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#hide_bike_toggle').click (e) ->
      pagespace.toggleHidden(e)
    $('#request-delete form').submit (e) ->
      e.preventDefault()
      pagespace.requestDelete()

  toggleHidden: (e) ->
    e.preventDefault()
    $('#hide_bike_toggle_group input').val('true')
    window.pageScript.submitBikeEditForm()

  requestDeleteRequestCallback: (data, success) ->
    # BikeIndex.alertMessage('success', 'Bike delete submitted', "Deleting your bike now. We delete all bikes by hand, it could take up to a day before your bike is gone. Thanks for your patience!")
    # BikeIndex.alertMessage('error', 'Request failed', "Oh no! Something went wrong and we couldn't send the delete request.")
    $('#request-delete').modal('hide')
    window.pageScript.submitBikeEditForm()

  requestDelete: ->
    reason = $('#bike_delete_reason').val()
    bike_id = $('#bike_delete_bike_id').val()
    if reason.length > 0 && bike_id.length > 0
      data =
        request_type: 'bike_delete_request'
        request_bike_id: bike_id
        request_reason: reason
      response_callback = @requestDeleteRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $('#request-delete-error').slideDown('fast').removeClass('currently-hidden')