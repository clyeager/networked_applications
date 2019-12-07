require 'socket'

def parse_request(request_line)
  http_method = s.scan(/[A-Z]+\s/)[0].strip
  path = s.scan(/\s\w?\//)[0].strip
  params = s.scan(/\?.+\s/)[0].split('&').each { |param| param.gsub!(/[? ]/, '') }

  hash_params = (params || "").each_with_object({}) do |pair, hash|
    k, v = pair.split('=')
    hash[k] = v
  end
end

server= TCPServer.new('localhost', 3003)
loop do
  client = server.accept

  request_line = client.gets
  puts request_line

  next unless request_line

  http_method, path, params = parse_request(request_line)

  client.puts "HTTP 1.0 200 OK"
  client.puts "Content-Type: text/html"
  client.puts
  client.puts "<html>"
  client.puts "<body>"
  client.puts "<pre>"
  client.puts http_method
  client.puts path
  client.puts params
  client.puts "</pre>"

  client.puts "<h1>Counnter</h1>"

  client.puts "<p>The current number is #{number}.</p>"

  client.puts <"href='?number=#{number + 1}'>Add one</a>"
  client.puts <"href='?number=#{number - 1}'>Subtract one</a>"
  client.puts "</body>"
  client.puts "</html>"

  client.close
end