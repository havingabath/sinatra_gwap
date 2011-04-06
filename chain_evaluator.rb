class ChainEvaluator
  def initialize chain
    @chain = chain
    @original = @chain.candidate.sentence
    @submission = @chain.l1attempt.sentence
  end
  
  def mark    #template_method
    @score = 0
    @score += check_no_of_words @submission #
    @score += check_words @submission #
    @score += check_word_order @submission #
    #@score += check_versus_machine    #TO BE INCLUDED LATER
    @score += check_perfect #
    
    @chain.l1attempt.player.add_score @score 
    @chain.l2attempt.player.add_score @score
    @chain.score = @score
    @chain.save
        
    @score
  end
  
  def check_no_of_words evaluee
    difference = (evaluee.split.size - @original.split.size).abs
    #puts "\nnumber of words: #{if difference == 0 then "perfect_match!" else "#{difference} words out" end}"
    
     case difference
              when 0
                #puts "100pts"
               100
              when 1
                #puts "50pts"
                 50
              when 2
                #puts "10pts"
                10
              else
                 0
              end
  end
  
  def check_words evaluee
    #create arrays of words from original and submission strings
    s_array = evaluee.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    o_array = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/," ").split
    
    check_words_score = 0
    
    puts "\nchecking words..."
    
    #check each word in turn, remove words that are scored on as you go to prvent scoring for including same word twice
    s_array.each do |word|
      if o_array.include? word
        #puts "#{word} - 50pts"
        check_words_score += 50
        o_array.delete_at(o_array.index(word))
      end
    end 
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
    #puts "\nword order score - #{word_order_score}pts"
    word_order_score
  end
  
  def check_perfect
    s_strip_string = @submission.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    o_strip_string = @original.downcase.gsub(/[\.,-\/#!$%\^&\*;:{}=\-_`~()?]/,"")
    
    bonus = 0
    
    #puts"\nChecking bonuses...."
    
    if s_strip_string == o_strip_string
      #puts"word order/words bonus - 100pts"
      bonus += 100
    end
    
    if @submission == @original
      #puts"exact match bonus - 200pts"
      bonus += 200
    end
    bonus
  end
end