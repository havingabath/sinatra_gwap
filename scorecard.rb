#REST relating to scorecards

#returns scorecard for completed chain
get '/score_page' do
  @chain = Chain.get(session[:chain])
  scorer = ChainEvaluator.new @chain
  @score = scorer.mark
  @score_card = scorer.get_l1_scorecard
  session[:chain] = nil
  @title = 'Score Page' 
  erb :score_page
end

#displays all a user's scorecards, dividing them into those they have viewed and those they haven't
get '/display_scorecards' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    @unviewed_score_cards = Scorecard.all(:player => @player, :viewed => false, :order => :created_at.desc)
    @viewed_score_cards = Scorecard.all(:player => @player, :viewed => true, :order => :created_at.desc)
    @title = "My Score Cards"
    erb :display_scorecards
  end
end

#display scorecard of parameter id
get '/scorecard/:id' do
  @score_card = Scorecard.get(params[:id])
  @title = "Score Card #{params[:id]}"
  erb :score_page
end
