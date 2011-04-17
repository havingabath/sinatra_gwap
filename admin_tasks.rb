get'/admin_data' do
  if @player && @player.name == "Admin"
    @candidates = Candidate.all
    @chains = Chain.all
    @players = Player.all
    @score_cards = Scorecard.all
    @title = 'Admin data'
    erb :admin_data
  else
    @title = "Not Admin"
    redirect '/'
  end
end

get '/chain/:id/delete' do 
  if @player && @player.name == "Admin" 
    l1 = L1attempt.get params[:id]
    l2 = L2attempt.get params[:id]
    chain = Chain.get params[:id]
    l1.destroy if l1
    l2.destroy if l2
    chain.destroy if chain  
    redirect '/admin_data'
  else
    @title = "Not Admin"
    redirect '/'
  end  
end


get '/clear_db' do
  if @player && @player.name == "Admin"
    L1attempt.destroy
    L2attempt.destroy
    Chain.destroy
    Candidate.destroy
    Scorecard.destroy
    Player.destroy
    redirect '/'
  else
    @title = "Not Admin"
    redirect '/'
  end
end