set :assets, Sprockets::Environment.new

settings.assets.append_path "assets/css"
settings.assets.append_path "assets/js"
settings.assets.append_path "components"
settings.assets.append_path "components/bootstrap/docs/assets/js"

get %r|/css/(.+\.css)| do
  content_type "text/css"
  settings.assets["#{params[:captures].first}"] or 404
end

get '/js/:file.js' do
  content_type "application/javascript"
  settings.assets["#{params[:file]}.js"] or
    settings.assets["#{params[:file]}/#{params[:file]}.js"] or
    404
end

get %r|/js/(.+\.js)| do
  content_type "application/javascript"
  settings.assets["#{params[:captures].first}"] or 404
end
