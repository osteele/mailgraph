set :assets, Sprockets::Environment.new

settings.assets.append_path "assets/css"
settings.assets.append_path "assets/js"

get %r|/css/(.+\.css)| do
  content_type "text/css"
  settings.assets["#{params[:captures].first}"]
end

get %r|/js/(.+\.js)| do
  content_type "application/javascript"
  settings.assets["#{params[:captures].first}"]
end
