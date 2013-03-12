$ ->
  $('.me').click ->
    window.location = "/me?user_id=#{user.id}&address_id=#{$(this).parent('.address').attr('id').replace(/address_/, '')}"
