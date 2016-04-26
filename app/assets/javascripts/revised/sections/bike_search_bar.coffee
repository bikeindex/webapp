class BikeIndex.BikeSearchBar extends BikeIndex
  constructor: (target_selector = '#bike_search_form #query') ->
    @initializeHeaderSearch($(target_selector))

  updateIncludeSerialOption: ($query_field) ->
    # Check if the header search includes the serial string match, set it on the window
    query_val = $query_field.val()
    window.includeSerialOption = !(query_val.match(/s(#|%23)[^(#|%23)]*(#|%23)/))

  initializeHeaderSearch: ($query_field) ->
    initial_opts = if $query_field.data('initial') then $query_field.data('initial') else []
    per_page = 15
    renderOption = @renderOption
    updateIncludeSerialOption = @updateIncludeSerialOption
    $query_field.selectize
      plugins: ['restore_on_backspace', 'remove_button']
      create: true
      options:  initial_opts # So that they have words
      items: _.map(initial_opts, 'search_id')
      persist: false # Don't show items the users has entered after deleting them
      valueField: 'search_id'
      preload: true
      labelField: 'text'
      searchField: 'text'
      loadThrottle: 150
      score: (search) ->
        score = this.getScoreFunction(search)
        return (item) ->
          if item.id == 'serial'
            # Only show serial query that is the same as the query we've entered
            if search == item.search && search.length > 2
              return 0.0001
            else
              return 0
          else
            score(item) * (1 + Math.min(item.priority / 100, 1))
      sortField: 'priority'
      load: (query, callback) ->
        that = this
        $.ajax
          url: "/api/autocomplete?per_page=#{per_page}&q=#{encodeURIComponent(query)}"
          type: 'GET'
          error: ->
            callback()
          success: (res) ->
            result = res.matches.slice(0, per_page)
            # Only add serial option if they've entered more than 2 char
            if query.length > 2 && window.includeSerialOption
              result.push({ id: 'serial', search_id: "s##{query}#", text: "#{query}", search: query })
            callback result
      render:
        option: (item, escape) ->
          renderOption(item, escape)
        item: (item, escape) ->
          if item.id == 'serial'
            "<div><span class='search_span_s'>serial</span> #{item.text}</div>"
          else  
            "<div> #{item.text}</div>"
        option_create: (data, escape) ->
          # For some reason, without &hellip; at the end of this it breaks
          "<div class='create'><span class='sch_'>Search all bikes for</span> <span class='label'>" + escape(data.input) + "</span>&hellip;</div>"
      onChange: (value) ->
        # On change doesn't cover everything, so run it all the time
        updateIncludeSerialOption($query_field)
        true
      onType: (str) ->
        for k in Object.keys(this.options)
          # If they are serial ids
          if k.match /^s\#/ 
            # if the serials are longer than the current str, delete them
            # Also delete them if we're down to 2 chars
            delete this.options[k] if (k.length > str + 3) || str.length < 3
        true
      onItemAdd: (value, $item) ->
        updateIncludeSerialOption($query_field)
        true
      onItemRemove: (value) ->
        updateIncludeSerialOption($query_field)
        true
      onInitialize: ->
        updateIncludeSerialOption($query_field)

  renderOption: (item, escape) ->
    prefix = switch
      when item.category == 'colors'
        p = "<span class='sch_'>Bikes that are </span>"
        if item.display
          p + "<span class='sclr' style='background: #{item.display};'></span>"
        else
          p + "<span class='sclr'>stckrs</span>"
      when item.category == 'mnfg' || item.category == 'frame_mnfg'
        "<span class='sch_'>Bikes made by</span>"
      when item.id == 'serial' # because we set this item up in the success callback
        "<span class='sch_'>Find serial</span>"
      else
        'entered'
    "<div>#{prefix} <span class='label'>" + escape(item.text) + '</span></div>'