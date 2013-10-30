require "strscan"

module SqlLexer
  class Lexer
    # SQL identifiers and key words must begin with a letter (a-z, but also
    # letters with diacritical marks and non-Latin letters) or an underscore
    # (_). Subsequent characters in an identifier or key word can be letters,
    # underscores, digits (0-9), or dollar signs ($). Note that dollar signs
    # are not allowed in identifiers according to the letter of the SQL
    # standard, so their use might render applications less portable. The SQL
    # standard will not define a key word that contains digits or starts or
    # ends with an underscore, so identifiers of this form are safe against
    # possible conflict with future extensions of the standard.
    StartID       = %q<\p{Alpha}_>
    PartID        = %q<\p{Alnum}_$>
    OpPart        = %q<\+|\-(?!-)|\*|/(?!\*)|\<|\>|=|~|!|@|#|%|\^|&|\||\?|\.|\(|\)>
    WS            = %q< \t\r\n>
    OptWS         = %Q<[#{WS}]*>

    StartQuotedID = %Q<">
    StartTickedID = %Q<`>
    StartString   = %Q<'>
    StartDigit    = %q<[\p{Digit}\.]>
    StartBind     = %Q<#{StartString}|#{StartDigit}>
    StartNonBind  = %Q<#{StartQuotedID}|#{StartTickedID}>
    StartAnyId    = %Q<"#{StartID}>

    AfterID       = %Q<[#{WS};#{StartNonBind}]|(?:#{OpPart})|$>
    ID            = %Q<[#{StartID}][#{PartID}]*(?=#{AfterID})>
    AfterOp       = %Q<[#{WS}]|[#{StartAnyId}]|[#{StartBind}]|$>
    Op            = %Q<(?:#{OpPart})+(?=#{AfterOp})>
    QuotedID      = %Q<#{StartQuotedID}(?:[^"]|"")*">
    TickedID      = %Q<#{StartTickedID}(?:[^`]|``)*`>
    NonBind       = %Q<#{ID}|#{Op}|#{QuotedID}|#{TickedID}>

    String        = %Q<#{StartString}(?:[^']|'')*'>

    Digits        = %q<\p{Digit}+>
    OptDigits     = %q<\p{Digit}*>
    Exponent      = %Q<e[+\-]?#{Digits}>
    OptExponent   = %Q<(?:#{Exponent})?>
    HeadDecimal   = %Q<#{Digits}\\.#{OptDigits}#{OptExponent}>
    TailDecimal   = %Q<#{OptDigits}\\.#{Digits}#{OptExponent}>
    ExpDecimal    = %Q<#{Digits}#{Exponent}>

    Number        = %Q<#{HeadDecimal}|#{TailDecimal}|#{ExpDecimal}|#{Digits}>

    TkWS          = %r<[#{WS}]+>
    TkOptWS       = %r<[#{WS}]*>
    TkOp          = %r<[#{OpPart}]>
    TkNonBind     = %r<#{NonBind}>
    TkID          = %r<#{ID}>
    TkEnd         = %r<;?[#{WS}]*>
    TkBind        = %r<#{String}|#{Number}>

    STATE_HANDLERS = {
      begin:    :process_begin,
      tokens:   :process_tokens,
      bind:     :process_bind,
      non_bind: :process_non_bind,
      end:      :process_end
    }

    def self.bindify(string)
      new(string).tap do |scanner|
        scanner.process
        return scanner.output, scanner.binds
      end
    end

    attr_reader :output, :binds

    def initialize(string)
      @scanner = StringScanner.new(string)
      @state   = :begin
      @output  = string.dup
      @binds   = []
    end

    def process
      while @state
        if ENV["DEBUG"]
          p @state
          p @scanner
        end

        send STATE_HANDLERS[@state]
      end

      pos = 0
      removed = 0
      extracted_binds = Array.new(@binds.size / 2)

      while pos < @binds.size
        slice = @output.slice!(@binds[pos] - removed, @binds[pos+1])
        @output.insert(@binds[pos] - removed, '?')
        extracted_binds[pos/2] = slice
        removed += slice.size - 1
        pos += 2
      end

      @binds = extracted_binds
    end

    def process_begin
      @scanner.scan(TkOptWS)
      @state = :tokens
    end

    def process_tokens
      @scanner.skip(TkOptWS)

      if @scanner.match?(TkBind)
        @state = :bind
      elsif @scanner.match?(TkNonBind)
        @state = :non_bind
      else
        @state = :end
      end
    end

    def process_non_bind
      @scanner.skip(TkNonBind)
      @state = :tokens
    end

    def process_bind
      pos = @scanner.pos
      size = @scanner.skip(TkBind)

      @binds << pos
      @binds << size

      @state = :tokens
    end

    def process_end
      @scanner.skip(TkEnd)

      unless @scanner.eos?
        raise "The SQL '#{@scanner.string}' could not be parsed"
      end

      @state = nil
    end
  end
end
