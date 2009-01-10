require 'rack'
require 'nanite/mapper'

module Nanite

  # This is a Rack app for nanite-admin.  You need to have an async capable
  # version of Thin installed for this to work.  See bin/nanite-admin for install
  # instructions.
  class Admin

    def initialize(agent)
      @agent = agent
    end

    AsyncResponse = [-1, {}, []].freeze

    def call(env)
      req = Rack::Request.new(env)
      if cmd = req.params['command']
        Nanite.request(cmd, req.params['payload'], :selector => req.params['type'], :timeout => 15) do |response|
          if response
            env['async.callback'].call [200, {'Content-Type' => 'text/html'}, [layout(ul(response))]]
          else
            env['async.callback'].call [500, {'Content-Type' => 'text/html'}, [layout("Request Timeout")]]
          end
        end
        AsyncResponse
      else
        [200, {'Content-Type' => 'text/html'}, layout]
      end
    end

    def services
      buf = "<select name='command'>"
      @agent.mapper.nanites.map{|k,v| v[:services]}.flatten.uniq.each do |srv|
        buf << "<option value='#{srv}'>#{srv}</option>"
      end
      buf << "</select>"
      buf
    end

    def ul(hash)
      buf = "<ul>"
      hash.each do |k,v|
        buf << "<li>identity : #{k}<br />response : #{v.inspect}</li>"
      end
      buf << "</ul>"
      buf
    end

    def layout(content="")
      %Q{
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns='http://www.w3.org/1999/xhtml'>
          <head>
            <meta content='text/html; charset=utf-8' http-equiv='Content-Type' />
            <meta content='en' http-equiv='Content-Language' />
            <meta content='Engineyard' name='author' />
            <title>Nanite Control Tower</title>

            <!-- Google AJAX Libraries API -->
            <script src="http://www.google.com/jsapi"></script>
            <script type="text/javascript">
              google.load("jquery", "1");
            </script>

            <script type="text/javascript">
            $(document).ready(function(){

              // set the focus to the payload field
              $("#payload").focus();

            });
            </script>

            <style>
              body {margin: 1em 3em 1em 3em;}
              li {list-style-type: none; margin-bottom: 1em;}
            </style>

          </head>

          <body>

            <div id="header">
              <h2>Nanite Control Tower</h2>
            </div>

            <div id="content">
              <form method="post" action="/">
                <input type="hidden" value="POST" name="_method"/>

                  <label>Send</label>
                  <select name="type">
                    <option value="least_loaded">the least loaded nanite</option>
                    <option value="random">a random nanite</option>
                    <option value="all">all nanites</option>
                    <option value="rr">a nanite chosen by round robin</option>
                  </select>

                  <label>providing service</label>
                  #{services}

                  <label>the payload</label>
                  <input type="text" class="text" name="payload" id="payload"/>

                  <input type="submit" class="submit" value="Go!" name="submit"/>
              </form>

              <h2>nanite responses:</h2>
              #{content}

              <h2>running nanites:</h2>
              <ul>
                #{@agent.mapper.nanites.map {|k,v| "<li>identity : #{k}<br />load : #{v[:status]}<br />services : #{v[:services].inspect}</li>" }.join}
              </ul>
            </div>

          </body>
        </html>
      }
    end # layout
  end # class Admin
end # module Nanite
