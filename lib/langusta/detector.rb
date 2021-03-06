module Langusta
  class Detector
    attr_accessor :verbose, :alpha, :max_text_length

    ALPHA_DEFAULT = 0.5
    ALPHA_WIDTH = 0.05
    ITERATION_LIMIT = 1000
    PROB_THRESHOLD = 0.1
    CONV_THRESHOLD = 0.99999
    BASE_FREQ = 10000
    UNKNOWN_LANG = "unknown"

    def initialize(factory)
      @word_lang_prob_map = factory.word_lang_prob_map
      @lang_list = factory.lang_list
      @text = []
      @langprob = nil
      @alpha = ALPHA_DEFAULT
      @n_trial = 7
      @max_text_length = 10000
      @prior_map = nil
      @verbose = false
    end
    
    # Append more text to be recognized.
    # @param text [UCS2String] text to be recognized
    def append(text)
      Guard.klass(text, Array, __method__)

      text = Codepoints.gsub!(text, RegexHelper::URL_REGEX, "\x00\x20")
      text = Codepoints.gsub!(text, RegexHelper::MAIL_REGEX, "\x00\x20")

      text = text.map do |c|
        NGram.normalize(c)
      end
      @text = Codepoints.gsub!(text, RegexHelper::SPACE_REGEX, "\x00\x20")
    end

    # Detect the language.
    # @return [String] (usually) two-letter code describing the language.
    def detect
      probabilities = get_probabilities()
      (probabilities.length > 0) ? probabilities.first.lang : UNKNOWN_LANG
    end

    private
    def detect_block
      cleaning_text()
      ngrams = extract_ngrams()
      raise NoFeaturesInTextError if ngrams.empty?
      @langprob = Array.new(@lang_list.length, 0.0)

      @n_trial.times do
        prob = init_probability()
        alpha = @alpha + Detector.next_gaussian() * ALPHA_WIDTH
        
        i = 0
        Kernel.loop do
          r = Kernel.rand(ngrams.length)
          update_lang_prob(prob, ngrams[r], alpha)
          if i % 5
            break if Detector.normalize_prob(prob) > CONV_THRESHOLD || i >= ITERATION_LIMIT
            # verbose
          end
        end
        @langprob.length.times do |j|
          @langprob[j] += prob[j] / @n_trial
        end
        # verbose
      end
    end

    def self.normalize_prob(prob)
      maxp = 0.0; sump = 0.0
      prob.each do |p|
        sump += p
      end
      prob.map! do |p|
        q = p / sump
        maxp = q if q > maxp
        q
      end
      maxp
    end

    def cleaning_text
      non_latin_count = latin_count = 0
      @text.each do |c|
        if c < 0x007a && c > 0x0041 # c > "z" && c < "A"
          latin_count += 1
        elsif c >= 0x3000 && UnicodeBlock.of(c) != UnicodeBlock::LATIN_EXTENDED_ADDITIONAL
          non_latin_count += 1
        end
      end
      if latin_count * 2 < non_latin_count
        text_without_latin = []
        @text.each do |c|
          text_without_latin << c if c > 0x007a || c < 0x0041 # c > "z" || c < "A"
        end
        @text = text_without_latin
      end
    end

    def extract_ngrams
      list = []
      ngram = NGram.new
      @text.each do |char|
        ngram.add_char(char)
        (1..NGram::N_GRAM).each do |n|
          w = ngram.get(n)
          list << w if w && @word_lang_prob_map.has_key?(w)
        end
      end
      list
    end

    def get_probabilities
      if @langprob.nil?
        detect_block()
      end
      sort_probability(@langprob)
    end

    def init_probability
      prob = Array.new(@lang_list.length)
      if @prior_map
        prob = @prior_map.clone
      else
        prob.length.times do |i|
          prob[i] = 1.0 / @lang_list.length
        end
      end
      prob
    end

    def sort_probability(prob)
      list = []
      prob.each_with_index do |prob, index|
        list[index] = Language.new(@lang_list[index], prob)
      end
      list.sort_by do |x|
        x.prob
      end.select do |x|
        x.prob > PROB_THRESHOLD
      end
    end

    def update_lang_prob(prob, word, alpha)
      return false if word.nil? || ! @word_lang_prob_map.has_key?(word)

      lang_prob_map = @word_lang_prob_map[word]
      # verbose
      weight = alpha / BASE_FREQ
      prob.length.times do |i|
        # tiny workaround for nil values in word freq array
        prob[i] *= weight + (lang_prob_map[i] || 0.0)
      end
      true
    end

    def word_prob_to_string(prob)
      prob.zip(@lang_list).select do |p, lang|
        p > 0.00001
      end.map do |p, lang|
        "%s:%.5f" % [p, lang]
      end.join(' ')
    end

    # Box-Muller transform.
    def self.next_gaussian
      s = 0
      while s >= 1 || s == 0
        v1 = 2 * Kernel.rand - 1
        v2 = 2 * Kernel.rand - 1
        s = v1 * v1 + v2 * v2
      end
      multiplier = Math.sqrt(-2 * Math.log(s)/s)
      return v1 * multiplier
    end
  end
end
