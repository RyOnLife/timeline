memoriesShowPhotoSelectorTemplate = require('templates/memories/memories_show_photo_selector')

class exports.MemoriesShowPhotoSelectorView extends Backbone.View
  id: 'photo_selector_view'
  
  state:
    limit: 60
    page: 1
    maxReached: false
    pendingRequest: false
  
  events:
    'click #select_from_container a': 'selectSource'
    'click #select_from_albums': 'showAlbums'
    'click #select_from_tagged': 'showTaggedPhotos'
    'change select': 'showAlbumPhotos'
    'click li[data-id]': 'selectPhoto'
  
  render: ->
    $(@el).html memoriesShowPhotoSelectorTemplate()
    @
    
  selectSource: (e) ->
    e.preventDefault()
    $el = $(e.currentTarget)
    if not $el.hasClass('selected')
      @reset()
      $el.parent().addClass('selected')
  
  showAlbums: (e) ->
    e.preventDefault()
    
    $el = $(@el)
    $el.find('option:gt(0)').remove()
    for album in USER.ALBUMS.data
      $el.find('select').append($('<option value="'+album.id+'">'+album.name+'&nbsp;</option>'))
    
    $(e.currentTarget).hide().siblings().show()
    $.centerCheat()
          
  showTaggedPhotos: (e) ->
    $('#photo_choices')
      .show()
      .find('ul')
        # Backbone scroll listener not working ???
        .unbind()
        .scroll (e) =>
          @infinityScroll(e, '/me/photos')
          @
        .trigger('scroll')

  infinityScroll: (e, url) ->
    $el = $(e.currentTarget)
    if (@state.page == 1 or 700 >= Math.ceil($el.find('li').length / 3) * 140 - $el.scrollTop()) and not @state.pendingRequest and not @state.maxReached
      
      @state.pendingRequest = true
      FB.api url, {limit: @state.limit, offset: (@state.page - 1) * @state.limit}, (response) =>
        
        for photos in response.data
          p = {}
          for photo in photos.images
            if photo.width <= 720 and not p.large
              p.large = photo
            else if photo.width <= 180 and not p.medium
              p.medium = photo
            else if photo.width <= 130 and not p.small
              p.small = photo
              break
          $photo = $('<li></li>')
            .attr('data-id', photos.id)
            .attr('data-small', p.small.source)
            .attr('data-medium', p.medium.source)
            .attr('data-large', p.large.source)
            .css('background', '#000 url('+p.medium.source+') no-repeat center center')
          $('#photo_choices ul').append($photo)
      
        $('#photo_choices ul li:nth-child(3n+2)').addClass('middle')
      
        if response.paging && response.paging.next
          @state.page++
        else
          @state.maxReached = true
      
        $('#photo_choices ul').css('background-image', 'none')
        @state.pendingRequest = false
  
  showAlbumPhotos: (e) ->
    @reset(partial=true)
    url = $(e.currentTarget).val()+'/photos'
    if url.length > 7
      $('#photo_choices')
        .show()
        .find('ul')
          .unbind()
          .scroll (e) =>
            @infinityScroll(e, url)
            @
          .trigger('scroll')
  
  selectPhoto: (e) ->
    $el = $(e.currentTarget)
    $photo = $('#photo a.add_photos')
    $photos = $('#photos li')
    
    if $photo.length
      # There is no main photo for the memory, so add it

      image = new Image()
      image.onload = ->
        $photo
          .removeClass('add_photos')
          .addClass('fb_gallery')
          .css({backgroundImage: 'url('+$el.attr('data-medium')+')', height: image.height})
          .attr('href', $el.attr('data-large'))
      image.src = $el.attr('data-medium')
    
    else if not $photos.find('a[href="'+$el.attr('data-large')+'"]').length
      # This photo is not already in the gallery, so add it
    
      background = '#000 url('+$el.attr('data-small')+') no-repeat center center'
      $link = $('<a href="'+$el.attr('data-large')+'" class="fb_gallery"><label></label></a>')
    
      if $photos.find('a.fb_gallery').length < $photos.length
        # Replace placeholder with a thumbnail
        $photos.each ->
          $this = $(this)
          if not $this.find('a.fb_gallery').length
            $this
              .find('a').remove().end()
              .css('background', background)
              .append($link)
            return false
      else
        # Thumbnail in a new row
        $newPhoto = $('<li></li>')
          .css('background', background)
          .append($link)
        $('#photos ul')
          .append($newPhoto)
          .append($('<li></li><li></li><li></li><li></li>'))
    
      # Ensure all thumbnails in the gallery are displayed
      $('#photos li').fadeIn()
      $('#show_photos').text('Hide Photos') if $photos.find('a.fb_gallery').length > 5
  
  reset: (partial=false)->
    # Resets the widget in its entirety
    if not partial
      $('#select_from_container')
        .find('div').removeClass('selected').end()
        .find('a').show().end()
        .find('select').hide().find('option:first').attr('selected', 'selected')
    # Resets the actual display of photos
    $('#photo_choices')
      .hide()
      .find('ul').css('background', 'transparent url(/web/img/spinner.gif) no-repeat center center')
      .find('li').remove()
    @state = _.extend(@state, {page: 1, maxReached: false, pendingRequest: false})
      