-- Copyright (C) 2010 Joe Noon (joe[at]stat.im)

module.host = "*" -- Global module

local httpeval_handshake = module:get_option("httpeval_handshake") or "HANDSHAKE";

local http = require "net.http";
local server = require "net.server";
local httpserver = require "net.httpserver";

local function getQueryParams(query)
  if type(query) == "string" and #query > 0 then
    if query:match("=") then
      local params = {};
      for k, v in query:gmatch("&?([^=%?]+)=([^&%?]+)&?") do
        if k and v then
          params[http.urldecode(k)] = http.urldecode(v);
        end
      end
      return params;
    else
      return http.urldecode(query);
    end
  end
end

function handle_request(method, body, request)
  local params = getQueryParams(request.url.query);
  
  if (not params) or (not params["handshake"]) or (params["handshake"] ~= httpeval_handshake) then
  	return "Error: Looks like an auth problem.";
	elseif (not body) or request.method ~= "POST" then
		return "Error: What?";
	elseif not method then
		module:log("debug", "Request %s suffered error %s", tostring(request.id), body);
		return;
	end
	module:log("debug", "Handling new request %s: %s\n----------", request.id, tostring(body));
	
	local code, err = loadstring(body);

	if err and not code then
	  return err;
	end

  local newgt = {};
  setmetatable(newgt, {__index = _G});
  setfenv(code, newgt);
	
	local ranok, taskok, message = pcall(code);
	
	if not ranok then
		return "Error: "..taskok;
	elseif not message then
		return "Result: "..tostring(taskok);
	elseif (not taskok) and message then
		return "Message: "..tostring(message);
	end
	
	return "OK: "..tostring(message);
end

local function setup()
	local ports = module:get_option("httpeval_ports") or { 8190 };
	local interface = module:get_option("httpeval_interface") or "127.0.0.1";
	httpserver.new_from_config(ports, handle_request, { base = "http-eval", interface = interface });
end
if prosody.start_time then -- already started
	setup();
else
	prosody.events.add_handler("server-started", setup);
end
