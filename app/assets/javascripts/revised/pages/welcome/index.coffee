class BikeIndex.WelcomeIndex extends BikeIndex
  constructor: ->
    $('#recovery-stories-container').removeClass('extras-hidden')
    $('#recovery-stories-container').slick
      infinite: false
      lazyLoad: 'ondemand'
