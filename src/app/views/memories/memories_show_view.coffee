memoriesShowTemplate = require('templates/memories/memories_show')

class exports.MemoriesShowView extends Backbone.View
  id: 'memories_show'
  
  events:
    'click a#tag_friends': 'showFriendSelector'
    'friendSelection a#tag_friends': 'updateFriendSelections'
    'click a#show_photos': 'showPhotos'
    'click a.add_photos': 'showPhotoSelector'
    'click a.fb_gallery': 'showGallery'
    'click a.fb_gallery label': 'removePhoto'
  
  render: ->
    $view = $(@el).html memoriesShowTemplate()
    $view.find('#photos').after app.views.memories_show_photo_selector.render().el
    @
    
  showFriendSelector: (e) ->
    e.preventDefault()
    FB.api '/me/friends', (response) -> $(e.currentTarget).fbFriendSelector(response.data, [])
  
  updateFriendSelections: (e, friends) ->
    $el = $(e.currentTarget)
    
    present = if friends.length == 1 then '1 person was there' else friends.length+' people were there'
    $('.friends .count').text(present)
    
    tagged = if friends.length then ' ('+friends.length+')' else ''
    $el
      .html('<span class="tag"></span> Tag Friends'+tagged)
      .css({'width': 'auto', 'display': 'inline-block'})
    $el.css({'width': $el.width(), 'display': 'block'})
    
  showPhotos: (e) ->
    e.preventDefault()
    $el = $(e.currentTarget)
    $p = $('#photos li')
    if $p.length > 5 and $p.filter(':visible').length < $p.length
      $el.text('Hide Photos')
      $('#photos li').fadeIn()
    else
      $el.text('Show All Photos ('+$p.find('a.fb_gallery').length+')')
      $('#photos li:gt(4)').fadeOut()
  
  showPhotoSelector: (e) ->
    e.preventDefault()
    $add = $('#add_photos')
    $ps = $('#photo_selector_view')
    if $ps.is(':visible')
      $add.text('Add Photos')
      $ps.fadeOut()
    else
      app.views.memories_show_photo_selector.reset()
      $add.text('Close')
      $ps.fadeIn()
        
  showGallery: (e) ->
    e.preventDefault()
    $pic = $(e.target)
    $pic.fbGallery() if $pic.filter('a').length # Do not open the gallery if the close button was clicked
    
  removePhoto: (e) ->
    $el = $(e.currentTarget)
    
    # Removing main photo
    if $el.parents('#photo').length
      
      $el.parent()
        .removeClass('fb_gallery')
        .addClass('add_photos')
        .css({backgroundImage: 'url(/web/img/add_photo.png)', height: 120})
        .attr('href', '#')
    
    # Removing photo from the gallery
    else
      
      # Remove the thumbnail
      $el.parents('li')
        .css('background', '#ECEFF5')
        .html('')
      
      # Put the add photos icon back in the fifth square, if it no longer has a thumbnail in it
      $fifthSquare = $('#photos ul li:nth-child(5)')
      if not $fifthSquare.find('a.fb_gallery').length
        $fifthSquare.html('<a href="/web/img/add_photo.png" class="add_photos"></a>')
        
      # Remove any entirely blank rows
      squares = Math.ceil($('#photos a.fb_gallery').length / 5) * 5 - 1
      $('#photos ul li:gt('+squares+')').remove()

      # Shift photos left if one from the middle of the grid is removed
      $photos = $('#photos a.fb_gallery')
      $photos.each (i) ->
        $this = $(@)
        $priorPhotoContainer = $this.parent().prev().filter('li')
        if $priorPhotoContainer.length and not $priorPhotoContainer.find('a').length
          bg = $this.parent().css('background-image')
          $this.parent().css('background', '#ECEFF5')
          $priorPhotoContainer
            .css('background-image', bg)
            .append($this)

      # No need for a hide photos link when there is only a single row in the grid
      $('a#show_photos').text('') if $photos.length <= 5
    