#REST relating to gameplay, i.e creating and updating chains

#creates a new chain when a player requests it, performs necessary checks
get '/new_chain' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    if @player.active_chains >= 5
      @title = "Too many active chains"
      erb :apology
    else
      #Do not use candidates the player entered
      candidates = Candidate.all(:player.not => @player) | Candidate.all(:player => nil)
      
      #only use candidates which the player speaks both languages
      suitable_candidates = candidates.select do |can|
                              @player.speaks?(can.source) && @player.speaks?(can.target)
                            end
                                
      #Do not use candidates, on which the user previously initiated a chain
      eligible_candidates = suitable_candidates.select do |can|
                              inclusion = true
                              can.chains.each do |ch|
                                inclusion = false if ch.l2attempt.player == @player
                              end
                              inclusion
                            end
  
      if (@candidate = eligible_candidates[rand(eligible_candidates.size)])
        chain = Chain.create(:candidate => @candidate)
        @l2attempt = L2attempt.create(:chain => chain, :player => @player, :recieved_at => Time.now)
        chain.save
        @l2attempt.save
        @title = 'Your New Trans-mission'
        erb :new_chain
      else
        @title = 'Lack of candidates in tower'
        erb :apology
      end
    end
  end
end

#player uses this to submit their L2attempt sentence
post '/submit_l2' do
  chain = Chain.get(params[:chain].to_i)
  l2 = L2attempt.get(params[:chain].to_i)
  
  if l2.filled == true
    @title = "Submission already recieved"
    erb :already_recieved
  else
    sentence_inspector = LanguageDetector.new params[:sentence]
  
    #if they are trying to cheat by using the same language
    if sentence_inspector.language == chain.candidate.source && sentence_inspector.confidence > 0.4 
      #penalise them and inform them of this
      @title = 'Penalty'
      @player = l2.player
      @penalty = @player.total_score / 10
      @player.total_score -= @penalty
      @player.save 
      l2.destroy
      chain.destroy
      erb :penalty
    elsif sentence_inspector.language != chain.candidate.target
      #don't penalise them but inform them the submission is unacceptable as language is not recognised target
      @title = 'Your New Trans-mission'
      @l2attempt = l2
      @candidate = chain.candidate
      flash[:notice] = "Your sentence was not recognised as #{chain.candidate.target_language}"
      erb :new_chain
    else  
      l2.sentence = params[:sentence]
      l2.filled = true
      l2.submitted_at = Time.now
      l2.chain.progress = 1         #stage L2 attempt filled
      l2.save
      flash[:notice] = "Your translation has been returned to the tower. You shall recieve your score card, when the chain is continued and completed by another player."
      redirect '/confirmation'
    end
  end
end


#serves up a chain to continue when a player requests it, performs necessary checks
get '/continue_chain' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    #find eligible chains, i.e. the logged-in player neither submitted candidate nor initiated the chain
    #the chains are at the right stage in progress, and the player speaks both target and source languages
    candidates = Candidate.all(:player.not => @player)
    chains = []
    candidates.each do |can|
      can.chains.each do |ch|
        if ch.progress == 1 && ch.l2attempt.player != @player
          if @player.speaks?(can.source) && @player.speaks?(can.target)
            chains << ch
          end
        end
      end
    end
  
    if chains.empty?
      @title = 'Lack of chains in tower'
      erb :apology
    else
      @chain = chains[rand(chains.size)]
      @l1attempt = L1attempt.create(:chain => @chain, :player => @player, :recieved_at => Time.now)
      @chain.progress = 2         #stage L1 attempt dispatched but unfilled
      @chain.save
      @title = 'Complete this Trans-mission'
      erb :continue_chain
    end
  end
end

  
#player uses this to submit their L1attempt sentence
post '/submit_l1' do
  l1 = L1attempt.get(params[:chain].to_i)
  
  if l1.filled == true
    @title = "Submission already recieved"
    erb :already_recieved
  else 
    #ensure language is what it is supposed to be
    sentence_inspector = LanguageDetector.new params[:sentence]
    if sentence_inspector.language != l1.chain.candidate.source
      @title = 'Complete Trans-mission'
      @l1attempt = l1
      @chain = l1.chain
      flash[:notice] = "Your sentence was not recognised as #{l1.chain.candidate.source_language}"
      erb :continue_chain
    else
      l1.sentence = params[:sentence]
      l1.filled = true
      l1.submitted_at = Time.now
      l1.chain.progress = 3         #stage L1 attempt filled
      l1.save
      session[:chain] = params[:chain].to_i
      redirect '/score_page'
    end
  end
end

#displays all chains of which player is involved but has yet to submit
get '/display_chains' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    l2attempts = L2attempt.all(:player => @player)
    l1attempts = L1attempt.all(:player => @player)
    @active_l2attempts = l2attempts.select{|l2| l2.chain.progress == 0}
    @active_l1attempts = l1attempts.select{|l1| l1.chain.progress == 2}
    @title = "My active chains"
    erb :display_chains
  end
end

#serves up active chain, and input screen to player on request
get '/new_chain/:id' do
  @l2attempt = L2attempt.get(params[:id])
  @candidate = @l2attempt.chain.candidate
  if @player == @l2attempt.player
    @title = "Your Trans-mission"
    erb :new_chain
  else
    @title = "Not your chain"
    erb :not_logged_in
  end
end

#serves up active chain, and input screen to player on request
get '/continue_chain/:id' do
  @chain = Chain.get(params[:id])
  @l1attempt = @chain.l1attempt
  
  if @player == @l1attempt.player
    @title = 'Complete this Trans-mission'
    erb :continue_chain
  else
    @title = "Not your chain"
    erb :not_logged_in
  end
end
