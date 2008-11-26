require 'rubygems'
require 'nanite'
require 'rack'
require 'nanite/mapper'

# you need raggi's patched async version of thin:
# git clone git://github.com/raggi/thin.git
# cd thin
# git branch async
# git checkout async
# git pull origin async_for_rack
# rake install
# thin -R nanite.ru -p 4000 start
 
class NaniteApp
  
  AsyncResponse = [-1, {}, []].freeze
    
  def call(env)
    AMQP.start :host => 'localhost', :user => 'mapper', :pass => 'testing',
               :vhost => '/nanite'
    Nanite.identity = "mapper"
    Nanite.mapper = Nanite::Mapper.new(15)
    def call(env)
      req = Rack::Request.new(env)
      if cmd = req.params['command']
        Nanite.request(cmd, req.params['payload'], :selector => req.params['type'], :timeout => 15) do |response| 
          if response
            env['async.callback'].call [200, {'Content-Type' => 'text/html'}, layout(ul(response))]
          else
            env['async.callback'].call [500, {'Content-Type' => 'text/html'}, "Request Timeout"]
          end    
        end
        AsyncResponse
      else
        [200, {'Content-Type' => 'text/html'}, layout]
      end    
    end
    [200, {'Content-Type' => 'text/html'}, "warmed up nanite mapper"]
  end
  
  def services
    buf = "<select name='command'>"
    Nanite.mapper.nanites.map{|k,v| v[:services]}.flatten.uniq.each do |srv|
      buf << "<option value='#{srv}'>#{srv}</option>"
    end
    buf << "</select>"
    buf
  end
  
  def ul(hash)
    buf = "<ul>"
    hash.each do |k,v|
      buf << "<li>#{k}: #{v.inspect}</li>"
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
        </head>  
        <body>
        <form method="post" action="/">
        <input type="hidden" value="POST" name="_method"/>
        <table class='search'>
          <tr>
            <td>
              <label>Send a Nanite command</label>
              #{services}
              <input type="text" class="text" name="payload"/>
              <select name="type">
                <option value="least_loaded">Least Loaded</option>
                <option value="random">Random</option>
                <option value="all">All</option>
                <option value="rr">Round Robin</option>
              </select>
            </td>
            <td>
              <input type="submit" class="submit" value="Make Request" name="submit"/>
            </td>
          </tr>
        </table>
        </form>
         #{content}
         <p>Nanites</p>
         <ul>
         #{Nanite.mapper.nanites.map {|k,v| "<li>#{k}: load:#{v[:status]}, services:#{v[:services].inspect}</li>" }.join}
         </ul>
        </body>
      </html>    
    }
  end
  
end


run NaniteApp.new
