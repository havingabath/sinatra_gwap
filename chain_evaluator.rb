#this class is in charge of the scoring algorithm and the creation of scorecards
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
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 50 %</p>"
      when 31..60
        @l1bonus = 0.4
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 40 %</p>"
      when 61..120
        @l1bonus = 0.3
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 30 %</p>"
      when 121..300
        @l1bonus = 0.2
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 20 %</p>"
      when 301..600
        @l1bonus = 0.1
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 10 %</p>"
      when 601..1800
        @l1bonus = 0.05
        @l1bonus_text = "<p>You took #{@l1time} seconds. Time Bonus of 5 %</p>"
      else
        @l1bonus = 0
        @l1bonus_text = "<p>You took #{@l1time} seconds. No time bonus</p>"
      end
      
      case @l2time 
        when 0..30
          @l2bonus = 0.5
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 50 %</p>"
        when 31..60
          @l2bonus = 0.4
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 40 %</p>"
        when 61..120
          @l2bonus = 0.3
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 30 %</p>"
        when 121..300
          @l2bonus = 0.2
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 20 %</p>"
        when 301..600
          @l2bonus = 0.1
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 10 %</p>"
        when 601..1800
          @l2bonus = 0.05
          @l2bonus_text = "<p>You took #{@l2time} seconds. Time Bonus of 5 %</p>"
        else
          @l2bonus = 0
          @l2bonus_text = "<p>You took #{@l2time} seconds. No time bonus</p>"
        end
  end
  
  def write_results
      @chain.score = @score
      @chain.save
      @score_card << "<p>TOTAL SCORE FOR CHAIN: #{@score} points</p>"
    
      l1_total = (@score * (1 + @l1bonus)).to_i
      @chain.l1attempt.player.add_score l1_total 
      @sc1 = Scorecard.new
      @sc1.report = @score_card + @l1bonus_text + "<p>Grand Total: #{l1_total} pts </p></div>"
      @sc1.chain = @chain
      @sc1.created_at = Time.now
      @sc1.player = @chain.l1attempt.player
      @sc1.save
     
      l2_total = (@score * (1 + @l2bonus)).to_i
      @chain.l2attempt.player.add_score l2_total
      @sc2 = Scorecard.new
      @sc2.report = @score_card + @l2bonus_text + "<p>Grand Total: #{l2_total} pts </p></div>"
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