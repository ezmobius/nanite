require 'rack'

module Nanite
  # This is a Rack app for nanite-admin.  You need to have an async capable
  # version of Thin installed for this to work.  See bin/nanite-admin for install
  # instructions.
  class Admin
    def initialize(mapper)
      @mapper = mapper
    end

    AsyncResponse = [-1, {}, []].freeze

    def call(env)
      req = Rack::Request.new(env)
      if cmd = req.params['command']
        @command = cmd
        @selection = req.params['type'] if req.params['type']
        
        options = {}
        case @selection
        when 'least_loaded', 'random', 'all', 'rr'
          options[:selector] = @selection
        else
          options[:target] = @selection
        end

        @mapper.request(cmd, req.params['payload'], options) do |response, responsejob|
          env['async.callback'].call [200, {'Content-Type' => 'text/html'}, [layout(ul(response, responsejob))]]
        end
        AsyncResponse
      else
        [200, {'Content-Type' => 'text/html'}, layout]
      end
    end

    def services
      buf = "<select name='command'>"
      @mapper.cluster.nanites.all_services.each do |srv|
        buf << "<option value='#{srv}' #{@command == srv ? 'selected="true"' : ''}>#{srv}</option>"
      end
      buf << "</select>"
      buf
    end

    def ul(hash, job)
      buf = "<ul>"
      hash.each do |k,v|
        buf << "<li><div class=\"nanite\">#{k}:</div><div class=\"response\">#{v.inspect}</div>"
        if job.intermediate_state && job.intermediate_state[k]
          buf << "<div class=\"intermediatestates\"><span class=\"statenote\">intermediate state:</span> #{job.intermediate_state[k].inspect}</div>"
        end
        buf << "</li>"
      end
      buf << "</ul>"
      buf
    end

    def layout(content=nil)
      %Q{
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns='http://www.w3.org/1999/xhtml'>
          <head>
            <meta content='text/html; charset=utf-8' http-equiv='Content-Type' />
            <meta content='en' http-equiv='Content-Language' />
            <meta content='Engineyard' name='author' />
            <title>Nanite Control Tower</title>

            <style>
              body {margin: 0; font-family: verdana; background-color: #fcfcfc;}
              ul {margin: 0; padding: 0; margin-left: 10px}
              li {list-style-type: none; margin-bottom: 6px}
              li .nanite {font-weight: bold; font-size: 12px}
              li .response {padding: 8px}
              li .intermediatestates {padding: 8px; font-size: 10px;}
              li .intermediatestates span.statenote {font-style: italic;}
              h1, h2, h3 {margin-top: none; padding: none; margin-left: 40px;}
              h1 {font-size: 22px; margin-top: 40px; margin-bottom: 30px; border-bottom: 1px solid #ddd; padding-bottom: 6px;
                margin-right: 40px}
              h2 {font-size: 16px;}
              h3 {margin-left: 0; font-size: 14px}
              .section {border: 1px solid #ccc; background-color: #fefefe; padding: 10px; margin: 20px 40px; padding: 20px;
                font-size: 14px}
              #footer {text-align: center; color: #AAA; font-size: 12px}
            </style>

          </head>

          <body>
            <div id="header">
              <h1>Nanite Control Tower</h1>
            </div>

            <h2>#{@mapper.options[:vhost]}</h2>
            <div class="section">
              <form method="post" action="/">
                <input type="hidden" value="POST" name="_method"/>

                  <label>Send</label>
                  <select name="type">
                    <option #{@selection == 'least_loaded' ? 'selected="true"' : ''} value="least_loaded">the least loaded nanite</option>
                    <option #{@selection == 'random' ? 'selected="true"' : ''} value="random">a random nanite</option>
                    <option #{@selection == 'all' ? 'selected="true"' : ''} value="all">all nanites</option>
                    <option #{@selection == 'rr' ? 'selected="true"' : ''} value="rr">a nanite chosen by round robin</option>
                    #{@mapper.cluster.nanites.map {|k,v| "<option #{@selection == k ? 'selected="true"' : ''} value='#{k}'>#{k}</option>" }.join}
                  </select>

                  <label>providing service</label>
                  #{services}

                  <label>the payload</label>
                  <input type="text" class="text" name="payload" id="payload"/>

                  <input type="submit" class="submit" value="Go!" name="submit"/>
              </form>

              #{"<h3>Responses</h3>" if content}
              #{content}
            </div>

            <h2>Running nanites</h2>
            <div class="section">
              #{"No nanites online." if @mapper.cluster.nanites.size == 0}
              <ul>
                #{@mapper.cluster.nanites.map {|k,v| "<li>identity : #{k}<br />load : #{v[:status]}<br />services : #{v[:services].to_a.inspect}<br />tags: #{v[:tags].to_a.inspect}</li>" }.join}
              </ul>
            </div>
            <div id="footer">
              Nanite #{Nanite::VERSION}
              <br />
              &copy; 2009 a bunch of random geeks
            </div>
          </body>
        </html>
      }
    end
  end
end
