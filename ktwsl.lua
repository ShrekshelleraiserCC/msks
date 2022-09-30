--- Krist Transaction Websocket Library
-- This is a simple library for establishing a websocket with a krist server
-- And then listening to transaction events.

-- To get started simply require this file, then call the returned function providing your krist endpoint URL, and private key.
-- Then call setTransactionHandler on the returned table. This function will be called with any events that occur.
-- You can use the parseMetadata method from the returned table to parse Krist metadata.
-- You can send websocket messages via wsReq, it'll automatically add the `id` field for you, and will yield until it recieves a relevant response.

-- When you're ready to start processing webhook requests, just call the start method, passing in any functions you want to run in parallel and protected.

-- Copyright 2022 Mason Gulu
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local function parseMetadata(s)
  local t={}
  for str in string.gmatch(s, "([^;]+)") do
    table.insert(t, str)
  end
  local ret = {}
  for k,v in pairs(t) do
    local kvpair = {}
    for str in string.gmatch(v, "([^=]+)") do
      table.insert(kvpair, str)
    end
    if #kvpair > 1 then
      -- key value pair
      ret[kvpair[1]] = kvpair[2]
    else
      ret[#ret+1] = kvpair[1]
    end
  end
  return ret
end

return function(url, privateKey)
  assert(url, "No URL provided")
  assert(privateKey, "No privateKey provided")
  local transactionHandler
  local ws
  local id = 0
  local queue = {}
  local function wsReq(T)
    T.id = id
    id = id + 1
    local msg = textutils.serialiseJSON(T)
    ws.send(msg)
    while true do
      local message = assert(ws.receive(), "Websocket dropped")
      local messageT = assert(textutils.unserialiseJSON(message), "Malform message")
      if messageT.id == T.id then
        return messageT
      end
    end
  end

  local function getWebsocketUrl()
    print("Getting websocket URL...")
    local resp = assert(http.post({
      url = url.."/ws/start",
      body = textutils.serialiseJSON({
        privateKey = privateKey
      })
    }), "Error getting websocket URL")
    local code, name = resp.getResponseCode()
    assert(code == 200, "Got bad response, "..code.." "..(name or ""))
    print("Got websocket URL...")
    local content = resp.readAll()
    resp.close()
    local body = assert(textutils.unserialiseJSON(content), "Got malformed body")
    return body.url
  end

  local function websocketHandler()
    print("Subscribing to transactions...")
    wsReq({type="subscribe",event="transactions"})
    print("Listening for websocket events...")
    while true do
      local response = assert(ws.receive(), "Websocket dropped")
      response = assert(textutils.unserialiseJSON(response), "Invalid JSON")
      if response.type == "event" then
        print("adding to queue")
        queue[#queue+1] = response
      end
    end
  end

  local function handleQueue()
    while true do
      if #queue > 0 then
        -- there is an event in the queue to handle
        local event = table.remove(queue,1)
        print("Handling event...")
        transactionHandler(event)
      else
        sleep(1)
      end
    end
  end

  local function connectToWebsocket(wsUrl, ...)
    print("Attempting to connect to websocket...")
    ws = http.websocket(wsUrl)
    print("Connected to websocket!")
    local stat, err = pcall(parallel.waitForAll, handleQueue, websocketHandler, ...)
    ws.close()
    print("Exited safely with error: "..err)
    return err
  end

  local api = {}
  function api.start(...)
    assert(transactionHandler, "No transaction handler provided")
    return connectToWebsocket(getWebsocketUrl(), ...)
  end

  function api.setTransactionHandler(handler)
    transactionHandler = handler
  end

  api.wsReq = wsReq
  api.ws = ws
  api.parseMetadata = function(...) return parseMetadata(...) end

  return api

end