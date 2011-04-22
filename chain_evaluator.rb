#this class is in charge of the scoring algorithm and the creation of scorecards
class ChainEvaluator
  def initialize chain
    @chain = chain
    @original = @chain.candidate.sentence
    @submission = @chain.l1attempt.sentence
    #the following two calls were made possible by including the to_lang and httparty gems
    #it makes googles translate perform the same chain and assigns the result to @machine
    machine_l2 = @original.translate(@chain.candidate.target, :from => @chain.candidate.source)
    @machine = machine_l2.translate(@chain.candidate.source, :from => @chain.candidate.target)
    start_score_card
  end
  
  def start_score_card
    @score_card = "<div id= 'score_card'><p><h2>Score Card for Chain #{@chain.id}</h2></p>"
    @score_card << "<p><span id ='p1'>#{@chain.candidate.player ? @chain.candidate.player.name : 'guest'}</span> first entered: <span id ='p1text'>#{@original}</span></p>"
    @score_card << "<p><span id ='p2'>#{@chain.l2attempt.player.name}</span> translated that to: <span id ='p2text'>#{@chain.l2attempt.sentence}</span></p>"
    @score_card << "<p><span id ='p3'>#{@chain.l1attempt.player.name}</span> translated that back to: <span id ='p3text'>#{@submission}</span></p>"
  end
    
  
  def mark    #template_method
    @score = 0
    @score += check_no_of_words @submission #
    @score += check_words @submission #
    @score += check_word_order @submission #
    @score += check_versus_machine #
    @score += check_perfect #
    calculate_time_bonuses
    write_results
    @score
  end
  
  def calculate_time_bonuses
    @l1time = (@chain.l1attempt.submitted_at) - (@chain.l1attempt.recieved_at)
    @l2time = (@chain.l2attempt.submitted_at) - (@chain.l2attempt.recieved_at)
    
    case @l1time 
      when 0..30
        @l1bonus = 0.5
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>50%</span></p>"
      when 31..60
        @l1bonus = 0.4
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>40%</span></p>"
      when 61..120
        @l1bonus = 0.3
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>30%</span></p>"
      when 121..300
        @l1bonus = 0.2
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>20%</span></p>"
      when 301..600
        @l1bonus = 0.1
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>10%</span></p>"
      when 601..1800
        @l1bonus = 0.05
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of <span id='bonus'>5%</span></p>"
      else
        @l1bonus = 0
        @l1bonus_text = "<p>You took #{@l1time} seconds. No time bonus</p>"
      end
      
      case @l2time 
        when 0..30
          @l2bonus = 0.5
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>50%</span></p>"
        when 31..60
          @l2bonus = 0.4
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>40%</span></p>"
        when 61..120
          @l2bonus = 0.3
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>30%</span></p>"
        when 121..300
          @l2bonus = 0.2
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>20%</span></p>"
        when 301..600
          @l2bonus = 0.1
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>10%</span></p>"
        when 601..1800
          @l2bonus = 0.05
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of <span id='bonus'>5%</span></p>"
        else
          @l2bonus = 0
          @l2bonus_text = "<p>You took #{@l2time} seconds. No time bonus</p>"
        end
  end
  
  def write_results
      @chain.score = @score
      @chain.save
      @score_card << "<p>TOTAL SCORE FOR CHAIN: <h5>#{@score}pts</h5></p>"
    
      l1_total = (@score * (1 + @l1bonus)).to_i
      @chain.l1attempt.player.add_score l1_total 
      @sc1 = Scorecard.new
      @sc1.report = @score_card + @l1bonus_text + "<p id='total'>GRAND TOTAL: #{l1_total} points </p></div>"
      @sc1.chain = @chain
      @sc1.created_at = Time.now
      @sc1.player = @chain.l1attempt.player
      @sc1.save
     
      l2_total = (@score * (1 + @l2bonus)).to_i
      @chain.l2attempt.player.add_score l2_total
      @sc2 = Scorecard.new
      @sc2.report = @score_card + @l2bonus_text + "<p id='total'>GRAND TOTAL: #{l2_total} points </p></div>"
      @sc2.chain = @chain
      @sc2.created_at = Time.now
      @sc2.player = @chain.l2attempt.player
      @sc2.save
  end
  
  def get_l1_scorecard
    @sc1
  end
    
  def check_no_of_words evaluee
    difference = (evaluee.split.size - @original.split.size).abs
    @score_card << "<p><h4>number of words:</h4> #{if difference == 0 then "perfect_match!" else "#{difference} words out" end}"
    
     case difference
              when 0
                @score_card << " - <h5>100pts</h5></p>"
               100
              when 1
                @score_card << " - <h5>50pts</h5></p>"
                 50
              when 2
                @score_card << " - <h5>10pts</h5></p>"
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
    
    @score_card << "<p><h4>Word matches...</h4></p>"
    
    #check each word in turn, remove words that are scored on as you go to prevent scoring for including same word twice
    s_array.each do |word|
      if o_array.include? word
        @score_card << "#{word} - <h5>50pts</h5>   "
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
    @score_card << "</p><p><h4>word order score </h4> <h5>#{word_order_score}pts</h5></p>"
    word_order_score
  end
  
  def check_versus_machine
    @score_card << "<p><h4>Versus machine score....</h4></p>"
    @score_card << "<div class = 'machine'><p>The machine entered: #{@machine}</p>"
    machine_score = 0
    bonus = 0
    
    machine_score += check_no_of_words @machine
    machine_score += check_words @machine
    machine_score += check_word_order @machine
    @score_card << "</div><p>Machine - #{machine_score}pts Vs Player - #{@score}pts</p>"
    
    if @score > machine_score
      @score_card <<  "<p>Beat the machine bonus: <h5>200pts</h5></p>"
      bonus += 200
    elsif @score == machine_score
      @score_card << "<p>Equal the machine bonus: <h5>100pts</h5></p>"
      bonus += 100
    else
      @score_card <<  "<p>The machine beat you this time....</p>"
    end
    bonus
  end
  
  def check_perfect
    s_strip_string = @submission.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    o_strip_string = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    
    bonus = 0
    
    @score_card << "<p><h4>Checking bonuses....</h4></p>"
    
    if s_strip_string == o_strip_string
      @score_card << "<p>word order/words bonus - <h5>100pts</h5></p>"
      bonus += 100
    end
    
    if @submission == @original
      @score_card << "<p>exact match bonus - <h5>200pts</h5></p>"
      bonus += 200
    end
    bonus
  end
end