$ ->
  $('.me').click ->
    window.location = "/user/#{user.id}me?address_id=#{$(this).parent('.address').attr('id').replace(/address_/, '')}"
