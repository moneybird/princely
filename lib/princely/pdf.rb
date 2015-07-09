module Princely
  class Pdf
    attr_accessor :executable, :style_sheets, :logger, :log_file, :server_flag, :media, :javascript

    # Initialize method
    #
    def initialize(options={})
      options = {
        :path => nil,
        :executable => Princely.executable,
        :log_file => nil,
        :logger => nil,
        :server_flag => false,
        :media => nil,
        :javascript => true
      }.merge(options)
      @executable = options[:path] ? Princely::Executable.new(options[:path]) : options[:executable]
      @style_sheets = ''
      @log_file = options[:log_file]
      @logger = options[:logger]
      @server_flag = options[:server_flag]
      @media = options[:media]
      @javascript = options[:javascript]
    end

    # Returns the instance logger or Princely default logger
    def logger
      @logger || Princely::Logging.logger
    end

    # Returns the instance log file or Princely default log file
    def log_file
      @log_file || Princely::Logging.filename
    end

    # Sets stylesheets...
    # Can pass in multiple paths for css files.
    #
    def add_style_sheets(*sheets)
      @style_sheets << sheets.map { |sheet| " -s #{sheet} " }.join(' ')
    end

    # Returns fully formed executable path with any command line switches
    # we've set based on our variables.
    #
    def exe_path
      @executable.join(executable_options)
    end

    def executable_options
      options = []
      options << "--input=html"
      options << "--server" if @server_flag
      options << "--media=#{media}" if media
      options << "--javascript" if @javascript
      options << @style_sheets
      options
    end

    # Makes a pdf from a passed in string.
    #
    # Returns PDF as a stream, so we can use send_data to shoot
    # it down the pipe using Rails.
    #
    def pdf_from_string(string, output_file = '-')
      pdf, errs = initialize_pdf_from_string(string, output_file, {:output_to_log_file => false})

      result = pdf.gets(nil)
      errors = errs.gets(nil)

      pdf.close
      errs.close

      result.force_encoding('BINARY') if RUBY_VERSION >= "1.9"

      if errors.present?
        handle_render_errors(errors)
      end

      result
    end

    def pdf_from_string_to_file(string, output_file)
      pdf, errs = initialize_pdf_from_string(string, output_file)
      pdf.close

      errors = errs.gets(nil)
      errs.close

      if errors.present?
        handle_render_errors(errors)
      end

      pdf
    end

    protected
    def initialize_pdf_from_string(string, output_file, options = {})
      options = {:log_command => true}.merge(options)
      path = exe_path
      # Don't spew errors to the standard out...and set up to take IO
      # as input and output
      path << " --media=#{media}" if media
      path << " --silent - -o #{output_file}"
      path << " --javascript" if @javascript

      log_command(path, string) if options[:log_command]
      stdin, stdout, stderr, _ = Open3.popen3(path)
      stdin.puts string
      stdin.close

      [stdout, stderr]
    end

    def log_command(path, source=nil)
      logger.info "\n\nPRINCE XML PDF COMMAND"
      logger.info path
      #logger.debug source if source
      logger.info ''
    end

    def handle_render_errors(errors)
      logger.error(errors)

      prince_errors = errors.scan(/^prince:\s(.*)$/)

      if prince_errors.any?
        raise Princely::RenderError.new(prince_errors)
      end
    end
  end
end
