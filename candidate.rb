#REST relating to adding and viewing candidates

get '/add_candidate' do    
  @title = 'Add Candidate'
  erb :add_candidate  
end

#adds candidate to system after performing necessary checks
post '/add_candidate' do
  #validate the candidate sentence
  @errors = []
  if params[:sentence].empty?
    @errors << "The sentence cannot be empty"
  elsif params[:sentence].split.size < 4
    @errors << "The sentence must contain at least four words"
  end
  if params[:source] == params[:target]
    @errors << "The target language must be different from the source language"
  end
  
  #ensure source language matches google language detect
  sentence_inspect = LanguageDetector.new params[:sentence]
  if sentence_inspect.language != params[:source]
    @errors << "The sentence is not recognisable #{Language.lang(params[:source])}"
  end
  
  unless @errors.empty?
    @title = 'Candidate Errors'
    @error_sentence = params[:sentence]
    erb :add_candidate
  else
    s = Candidate.new  
    s.sentence = params[:sentence]
    s.source = params[:source]
    s.target = params[:target]  
    s.created_at = Time.now
    if @player                    #if player is logged in save it to his candidates
      @player.candidates << s
      @player.save
    else                          #if it is a guest, just save it
      s.save 
    end     
    flash[:notice] = "Your Candidate has been submitted to the tower."
    redirect '/confirmation'
  end  
end

#displays a users candidates and associated translations
get '/display_candidates' do
  unless @player
    @title = "Please log in"
    erb :not_logged_in
  else
    @candidates = Candidate.all(:player => @player, :order => :created_at.desc)
    @title = "#{@player.name}'s Candidates"
    erb :display
  end
end
