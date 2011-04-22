#REST relating to login and registration

get '/register' do
  @title = 'Register'
  erb :register
end

#performs registration and creates new user
post '/register' do  
  p = Player.new  
  p.name = params[:name]
  p.email = params[:email]
  p.password = params[:password]
  
  languages = []
  if params[:en_lang]
    languages << :en
  end
  
  if params[:es_lang]
    languages << :es
  end
  
  if params[:ga_lang]
    languages << :ga
  end
  
  if params[:fr_lang]
    languages << :fr
  end
  
  
  p.languages = languages
  
    
  p.joined_at = Time.now
  if p.save
    session[:player] = p.id if p 
    flash[:notice] = "Your request to join the hordes of new Babylon has been submitted to the tower"
    redirect '/confirmation'
  else
    @title = 'Registration Errors'
    @errors = p.errors
    erb :register
  end  
end

get '/login' do
  @title = 'Log in'
  erb :login
end

#logs a player in
post '/login' do
  player = Player.first(:name => params[:name], :password => params[:password])
  
  if player
    session[:player] = player.id
    unviewed_score_cards = Scorecard.all(:player => player, :viewed => false)
    if unviewed_score_cards.size > 0
      flash[:notice] = "You have new Score Cards waiting..."
    end
    @title = "Player Control#{player.name}"
    @player = player
    erb :player_control
  else
    flash[:notice] = "That username and password combination was not recognised by the system"
    @title = "Username and password not recognised"
    erb :login
  end
end

get '/logout' do
  session[:player] = nil
  redirect '/'
end
