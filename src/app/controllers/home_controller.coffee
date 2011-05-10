class exports.HomeController extends Backbone.Controller
  routes :
    ''                     : 'oauth'
    'access_token=:params' : 'access_token'

  constructor: ->
    super

  home: ->
    $('#fb_wrapper').html(app.views.home_index.render().el)
  
  oauth: ->
    error = $.url().param('error')
    if error == 'access_denied'
      $.cookie('access_token', null)
    else
      top.location = 'http://www.facebook.com/dialog/oauth/?scope=publish_stream,user_birthday&client_id=121822724510409&redirect_uri=http://ryonlife.dyndns.org:8080/&response_type=token'

  access_token: (params) ->
    console.log(params)
    values = params.split('&expires_in=')
    $.cookie('access_token', values[0])
    location.hash = '/memories/new'