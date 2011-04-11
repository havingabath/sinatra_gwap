class ChainEvaluator
  def initialize chain
    @chain = chain
    @original = @chain.candidate.sentence
    @submission = @chain.l1attempt.sentence
    machine_l2 = @original.translate(@chain.candidate.target, :from => @chain.candidate.source)
    @machine = machine_l2.translate(@chain.candidate.source, :from => @chain.candidate.target)
    start_score_card
  end
  
  def start_score_card
    @score_card = "<div id= 'score_card'><p><h2>Score Card for Chain #{@chain.id}<h2></p>"
    @score_card << "<p>#{@chain.candidate.player.name} first entered: #{@original}</p>"
    @score_card << "<p>#{@chain.l2attempt.player.name} translated that to: #{@chain.l2attempt.sentence}</p>"
    @score_card << "<p>#{@chain.l1attempt.player.name} translated that back to: #{@submission}</p>"
  end
    
  
  def mark    #template_method
    @score = 0
    @score += check_no_of_words @submission #
    @score += check_words @submission #
    @score += check_word_order @submission #
    @score += check_versus_machine #
    @score += check_perfect #
    write_results
    @score
  end
  
  def write_results
      @chain.l1attempt.player.add_score @score 
      @chain.l2attempt.player.add_score @score
      @chain.score = @score
      @chain.save

      @score_card << "<p>TOTAL SCORE FOR CHAIN: #{@score} points</p></div>"
      @sc1 = Scorecard.new
      @sc2 = Scorecard.new
      @sc1.report = @sc2.report = @score_card
      @sc1.chain = @sc2.chain = @chain
      @sc1.player = @chain.l1attempt.player
      @sc2.player = @chain.l2attempt.player
      @sc1.save
      @sc2.save
  end
  
  def get_l1_scorecard
    @sc1
  end
    
  def check_no_of_words evaluee
    difference = (evaluee.split.size - @original.split.size).abs
    @score_card << "<p>number of words: #{if difference == 0 then "perfect_match!" else "#{difference} words out" end}"
    
     case difference
              when 0
                @score_card << " - 100pts</p>"
               100
              when 1
                @score_card << " - 50pts</p>"
                 50
              when 2
                @score_card << " - 10pts</p>"
                10
              else
                @score_card << "</p>"
                 0
              end
  end
  
  def check_words evaluee
    #create arrays of words from original and submission strings
    s_array = evaluee.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    o_array = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    
    check_words_score = 0
    
    @score_card << "<p>Word matches...</p>"
    
    #check each word in turn, remove words that are scored on as you go to prevent scoring for including same word twice
    s_array.each do |word|
      if o_array.include? word
        @score_card << "#{word} - 50pts   "
        check_words_score += 50
        o_array.delete_at(o_array.index(word))
      end
    end
    @score_card << "</p>" 
    check_words_score
  end
  
  def check_word_order evaluee
    s_array = evaluee.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    o_array = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    
    word_order_score = 0
    
    s_array.each_with_index do |word,i|
      if word == o_array[i]
        word_order_score += 20
      end
    end
    @score_card << "<p>word order score - #{word_order_score}pts</p>"
    word_order_score
  end
  
  def check_versus_machine
    @score_card << "<div class = \"machine\"><p>Versus machine score....</p>"
    @score_card << "<p>The machine entered: #{@machine}</p>"
    machine_score = 0
    bonus = 0
    
    @score_card <<  "<p>machine - </p>"
    machine_score += check_no_of_words @machine
    @score_card << "<p>machine -"
    machine_score += check_words @machine
    @score_card << "<p>machine -"
    machine_score += check_word_order @machine
    @score_card << "<p>Machine - #{machine_score} Vs Player - #{@score}</p>"
    
    if @score > machine_score
      @score_card <<  "<p>Beat the machine bonus: 200pts</p></div>"
      bonus += 200
    elsif @score == machine_score
      @score_card << "<p>Equal the machine bonus: 100pts</p></div>"
      bonus += 100
    else
      @score_card <<  "<p>The machine beat you this time</p></div>"
    end
    bonus
  end
  
  def check_perfect
    s_strip_string = @submission.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    o_strip_string = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    
    bonus = 0
    
    @score_card << "<p>Checking bonuses....</p>"
    
    if s_strip_string == o_strip_string
      @score_card << "<p>word order/words bonus - 100pts</p>"
      bonus += 100
    end
    
    if @submission == @original
      @score_card << "<p>exact match bonus - 200pts</p>"
      bonus += 200
    end
    bonus
  end
end