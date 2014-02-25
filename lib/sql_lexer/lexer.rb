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
    OpPart        = %q<\+|\-(?!-)|\*|/(?!\*)|\<|\>|=|~|!|@|#|%|\^|&|\||\?|\.|,|\(|\)>
    WS            = %q< \t\r\n>
    OptWS         = %Q<[#{WS}]*>
    End           = %Q<;|$>

    InOp          = %q<IN>
    ArrayOp       = %q<ARRAY>
    ColonColonOp  = %Q<::(?=[#{StartID}])>
    ArrayIndexOp  = %q<\\[(?:\-?\d+(?::\-?\d+)?|NULL)\\]>
    SpecialOps    = %Q<#{InOp}(?=[#{WS}])|#{ColonColonOp}|#{ArrayOp}|#{ArrayIndexOp}>

    StartQuotedID = %Q<">
    StartTickedID = %Q<`>
    StartString   = %Q<[a-zA-Z]?'>
    StartDigit    = %q<[\p{Digit}\.]>

    StartSelect   = %Q<SELECT(?=(?:[#{WS}]|#{OpPart}))>

    # Binds that are also IDs do not need to be included here, since AfterOp (which uses StartBind)
    # also checks for StartAnyId
    StartBind     = %Q<#{StartString}|#{StartDigit}|#{SpecialOps}>

    StartNonBind  = %Q<#{StartQuotedID}|#{StartTickedID}|\\$(?=\\p{Digit})>
    TableNext     = %Q<(#{OptWS}((?=#{StartQuotedID})|(?=#{StartTickedID}))|[#{WS}]+(?=[#{StartID}]))>
    StartAnyId    = %Q<"#{StartID}>
    Placeholder   = %q<\$\p{Digit}+>

    AfterID       = %Q<[#{WS};#{StartNonBind}]|(?:#{OpPart})|(?:#{ColonColonOp})|(?:#{ArrayIndexOp})|$>
    ID            = %Q<[#{StartID}][#{PartID}]*(?=#{AfterID})>
    AfterOp       = %Q<[#{WS}]|[#{StartAnyId}]|[#{StartBind}]|(#{StartNonBind})|$>
    Op            = %Q<(?:#{OpPart})+(?=#{AfterOp})>
    QuotedID      = %Q<#{StartQuotedID}(?:[^"]|"")*">
    TickedID      = %Q<#{StartTickedID}(?:[^`]|``)*`>
    NonBind       = %Q<#{ID}|#{Op}|#{QuotedID}|#{TickedID}|#{Placeholder}>
    Type          = %Q<[#{StartID}][#{PartID}]*(?:\\(\d+\\)|\\[\\])?(?=#{AfterID})>
    QuotedTable   = %Q<#{TickedID}|#{QuotedID}>

    StringBody    = %q{(?:''|(?<!\x5C)(?:\x5C\x5C)*\x5C'|[^'])*}
    String        = %Q<#{StartString}#{StringBody}'>

    Digits        = %q<\p{Digit}+>
    OptDigits     = %q<\p{Digit}*>
    Exponent      = %Q<e[+\-]?#{Digits}>
    OptExponent   = %Q<(?:#{Exponent})?>
    HeadDecimal   = %Q<#{Digits}\\.#{OptDigits}#{OptExponent}>
    TailDecimal   = %Q<#{OptDigits}\\.#{Digits}#{OptExponent}>
    ExpDecimal    = %Q<#{Digits}#{Exponent}>

    Number        = %Q<#{HeadDecimal}|#{TailDecimal}|#{ExpDecimal}|#{Digits}>

    Literals      = %Q<(?:NULL|TRUE|FALSE)(?=(?:[#{WS}]|#{OpPart}|#{End}))>

    TkWS          = %r<[#{WS}]+>u
    TkOptWS       = %r<[#{WS}]*>u
    TkOp          = %r<[#{OpPart}]>u
    TkComment     = %r<^#{OptWS}--.*$>u
    TkBlockCommentStart = %r</\*>u
    TkBlockCommentEnd   = %r<\*/>u
    TkPlaceholder = %r<#{Placeholder}>u
    TkNonBind     = %r<#{NonBind}>u
    TkType        = %r<#{Type}>u
    TkQuotedTable = %r<#{QuotedTable}>iu
    TkUpdateTable = %r<UPDATE#{TableNext}>iu
    TkInsertTable = %r<INSERT[#{WS}]+INTO#{TableNext}>iu
    TkDeleteTable = %r<DELETE[#{WS}]+FROM#{TableNext}>iu
    TkFromTable   = %r<FROM#{TableNext}>iu
    TkID          = %r<#{ID}>u
    TkEnd         = %r<;?[#{WS}]*>u
    TkBind        = %r<#{String}|#{Number}|#{Literals}>u
    TkIn          = %r<#{InOp}>iu
    TkColonColon  = %r<#{ColonColonOp}>u
    TkArray       = %r<#{ArrayOp}>iu
    TkArrayIndex  = %r<#{ArrayIndexOp}>iu
    TkSpecialOp   = %r<#{SpecialOps}>iu
    TkStartSelect = %r<#{StartSelect}>iu
    TkStartSubquery = %r<\(#{OptWS}#{StartSelect}>iu
    TkCloseParen  = %r<#{OptWS}\)>u

    STATE_HANDLERS = {
      begin:       :process_begin,
      first_token: :process_first_token,
      tokens:      :process_tokens,
      bind:        :process_bind,
      non_bind:    :process_non_bind,
      placeholder: :process_placeholder,
      table_name:  :process_table_name,
      end:         :process_end,
      special:     :process_special,
      subquery:    :process_subquery,
      in:          :process_in,
      array:       :process_array
    }

    def self.bindify(string, binds=nil)
      scanner = instance(string)
      scanner.process(binds)
      [scanner.title, scanner.output, scanner.binds]
    end

    attr_reader :output, :binds, :title

    def self.pooled_value(name, default)
      key = :"__skylight_sql_#{name}"

      singleton_class.class_eval do
        define_method(name) do
          value = Thread.current[key] ||= default.dup
          value.clear
          value
        end
      end

      __send__(name)
    end

    SCANNER_KEY = :__skylight_sql_scanner
    LEXER_KEY   = :__skylight_sql_lexer

    def self.scanner(string='')
      scanner = Thread.current[SCANNER_KEY] ||= StringScanner.new('')
      scanner.string = string
      scanner
    end

    def self.instance(string)
      lexer = Thread.current[LEXER_KEY] ||= new
      lexer.init(string)
      lexer
    end

    pooled_value :binds, []
    pooled_value :table, "*" * 20

    SPACE = " ".freeze

    DEBUG = ENV["DEBUG"]

    def init(string)
      @state   = :begin
      @debug   = DEBUG
      @binds   = self.class.binds
      @table   = self.class.table
      @title   = nil
      @bind    = 0

      self.string = string
    end

    def string=(value)
      @input   = value

      @scanner = self.class.scanner(value)

      # intentionally allocates; we need to return a new
      # string as part of this API
      @output = value.dup
    end

    PLACEHOLDER = "?".freeze
    UNKNOWN = "<unknown>".freeze

    def process(binds)
      process_comments

      @operation = nil
      @provided_binds = binds

      while @state
        if @debug
          p @state
          p @scanner
        end

        __send__ STATE_HANDLERS[@state]
      end

      pos = 0
      removed = 0

      # intentionally allocates; the returned binds must
      # be in a newly produced array
      extracted_binds = Array.new(@binds.size / 2)

      if @operation && !@table.empty?
        @title = "" << @operation << SPACE << @table
      end

      while pos < @binds.size
        if @binds[pos] == nil
          extracted_binds[pos/2] = @binds[pos+1]
        else
          slice = @output[@binds[pos] - removed, @binds[pos+1]]
          @output[@binds[pos] - removed, @binds[pos+1]] = PLACEHOLDER

          extracted_binds[pos/2] = slice
          removed += (@binds[pos+1] - 1)
        end

        pos += 2
      end

      @binds = extracted_binds
      nil
    end

    EMPTY = "".freeze

    def process_comments
      # SQL treats comments as similar to whitespace
      # Here we replace all comments with spaces of the same length so as to not affect binds

      # Remove block comments
      # SQL allows for nested comments so this takes a bit more work
      while @scanner.skip_until(TkBlockCommentStart)
        count = 1
        pos = @scanner.pos - 2

        while true
          # Determine whether we close the comment or start nesting
          next_open  = @scanner.skip_until(TkBlockCommentStart)
          @scanner.unscan if next_open
          next_close = @scanner.skip_until(TkBlockCommentEnd)
          @scanner.unscan if next_close

          if next_open && next_open < next_close
            # We're nesting
            count += 1
            @scanner.skip_until(TkBlockCommentStart)
          else
            # We're closing
            count -= 1
            @scanner.skip_until(TkBlockCommentEnd)
          end

          if count > 10_000
            raise "The SQL '#{@scanner.string}' could not be parsed because of too many iterations in block comments"
          end

          if count == 0
            # We've closed all comments
            length = @scanner.pos - pos
            # Dup the string if necessary so we aren't destructive to the original value
            @scanner.string = @input.dup if @scanner.string == @input
            # Replace the comment with spaces
            @scanner.string[pos, length] = SPACE*length
            break
          end
        end
      end

      @scanner.reset

      # Remove single line comments
      while @scanner.skip_until(TkComment)
        pos = @scanner.pos
        len = @scanner.matched_size
        # Dup the string if necessary so we aren't destructive to the original value
        @scanner.string = @input.dup if @scanner.string == @input
        # Replace the comment with spaces
        @scanner.string[pos-len, len] = SPACE*len
      end

      @scanner.reset
    end

    def process_begin
      @scanner.skip(TkOptWS)
      @state = :first_token
    end

    OP_SELECT_FROM = "SELECT FROM".freeze
    OP_UPDATE      = "UPDATE".freeze
    OP_INSERT_INTO = "INSERT INTO".freeze
    OP_DELETE_FROM = "DELETE FROM".freeze

    def process_first_token
      if @scanner.skip(TkStartSelect)
        @operation = OP_SELECT_FROM
        @state = :tokens
      else
        if @scanner.skip(TkUpdateTable)
          @operation = OP_UPDATE
        elsif @scanner.skip(TkInsertTable)
          @operation = OP_INSERT_INTO
        elsif @scanner.skip(TkDeleteTable)
          @operation = OP_DELETE_FROM
        end

        @state = :table_name
      end
    end

    def process_table_name
      pos = @scanner.pos

      if @scanner.skip(TkQuotedTable)
        copy_substr(@input, @table, pos + 1, @scanner.pos - 1)
      elsif @scanner.skip(TkID)
        copy_substr(@input, @table, pos, @scanner.pos)
      end

      @state = :tokens
    end

    def process_tokens
      @scanner.skip(TkOptWS)

      if @operation == OP_SELECT_FROM && @table.empty? && @scanner.skip(TkFromTable)
        @state = :table_name
      elsif @scanner.match?(TkSpecialOp)
        @state = :special
      elsif @scanner.match?(TkBind)
        @state = :bind
      elsif @scanner.match?(TkPlaceholder)
        @state = :placeholder
      elsif @scanner.match?(TkNonBind)
        @state = :non_bind
      else
        @state = :end
      end
    end

    def process_placeholder
      @scanner.skip(TkPlaceholder)

      binds << nil

      if !@provided_binds
        @binds << UNKNOWN
      elsif !@provided_binds[@bind]
        @binds << UNKNOWN
      else
        @binds << @provided_binds[@bind]
      end

      @bind += 1

      @state = :tokens
    end

    def process_special
      if @scanner.skip(TkIn)
        @scanner.skip(TkOptWS)
        if @scanner.skip(TkStartSubquery)
          @state = :subquery
        else
          @scanner.skip(/\(/u)
          @state = :in
        end
      elsif @scanner.skip(TkArray)
        @scanner.skip(/\[/u)
        @state = :array
      elsif @scanner.skip(TkColonColon)
        if @scanner.skip(TkType)
          @state = :tokens
        else
          @state = :end
        end
      elsif @scanner.skip(TkStartSubquery)
        @state = :subquery
      elsif @scanner.skip(TkArrayIndex)
        @state = :tokens
      end
    end

    def process_subquery
      nest = 1
      iterations = 0

      while nest > 0
        iterations += 1

        if iterations > 10_000
          raise "The SQL '#{@scanner.string}' could not be parsed because of too many iterations in subquery"
        end

        if @debug
          p @state
          p @scanner
          p nest
          p @scanner.peek(1)
        end

        if @scanner.skip(TkStartSubquery)
          nest += 1
          @state = :tokens
        elsif @scanner.skip(TkCloseParen)
          nest -= 1
          break if nest.zero?
          @state = :tokens
        elsif @state == :subquery
          @state = :tokens
        end

        __send__ STATE_HANDLERS[@state]
      end

      @state = :tokens
    end

    def process_in
      nest = 1
      iterations = 0

      @skip_binds = true
      pos = @scanner.pos - 1

      while nest > 0
        iterations += 1

        if iterations > 10_000
          raise "The SQL '#{@scanner.string}' could not be parsed because of too many iterations in IN"
        end

        if @debug
          p @state
          p @scanner
          p nest
        end

        if @scanner.skip(/\(/u)
          nest += 1
          process_tokens
        elsif @scanner.skip(TkCloseParen)
          nest -= 1
          break if nest.zero?
          process_tokens
        else
          process_tokens
        end

        __send__ STATE_HANDLERS[@state]
      end

      @binds << pos
      @binds << @scanner.pos - pos

      @skip_binds = false

      @state = :tokens
    end

    def process_array
      nest = 1
      iterations = 0

      @skip_binds = true
      pos = @scanner.pos - 6

      while nest > 0
        iterations += 1

        if iterations > 10_000
          raise "The SQL '#{@scanner.string}' could not be parsed because of too many iterations in ARRAY"
        end

        if @debug
          p "array loop"
          p @state
          p @scanner
        end

        if @scanner.skip(/\[/u)
          nest += 1
        elsif @scanner.skip(/\]/u)
          nest -= 1

          break if nest.zero?

          # End of final nested array
          next if @scanner.skip(/#{TkOptWS}(?=\])/u)
        end

        # A NULL array
        next if @scanner.skip(/NULL/iu)

        # Another nested array
        next if @scanner.skip(/#{TkOptWS},#{TkOptWS}(?=\[)/u)

        process_tokens

        __send__ STATE_HANDLERS[@state]
      end

      @binds << pos
      @binds << @scanner.pos - pos

      @skip_binds = false

      @state = :tokens
    end

    def process_non_bind
      @scanner.skip(TkNonBind)
      @state = :tokens
    end

    def process_bind
      pos = @scanner.pos
      size = @scanner.skip(TkBind)

      unless @skip_binds
        @binds << pos
        @binds << size
      end

      @state = :tokens
    end

    def process_end
      if @scanner.skip(TkEnd)
        if @scanner.eos?
          @state = nil
        else
          process_tokens
        end
      end

      # We didn't hit EOS and we couldn't process any tokens
      if @state == :end
        raise "The SQL '#{@scanner.string}' could not be parsed"
      end
    end

  private
    def copy_substr(source, target, start_pos, end_pos)
      pos = start_pos

      while pos < end_pos
        target.concat source.getbyte(pos)
        pos += 1
      end
    end

    scanner
    instance('')

  end
end
