--- Krist Transaction Websocket Library
-- This is a simple library for establishing a websocket with a krist server
-- And then listening to transaction events.

-- To get started simply require this file, then call the returned function providing your krist endpoint URL, and private key.
-- You may then subscribe to transactions sent to certain addresses by calling subscribeAddress

-- Make sure to call start

-- Once you've subscribed to some addresses and you've called start, events will begin to be thrown when certain things happen:
-- * "krist_transaction", toAddress, fromAddress, value, transactionTable
-- Be sure to listen for the error event too, if the websocket stops for any reason this event will be thrown and no further `"krist_transaction" events will be thrown
-- * "krist_stop", errorReason


-- Copyright 2022 Mason Gulu
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


local redrun = require("redrun")

---Parse CommonMeta data
---@param s string
---@return table metadata
local function parseMetadata(s)
  if not s then
    return {}
  end
  -- This is not valid.
  local hasName = not not s:gmatch("%a+%@?%a-%.kst")
  local t={}
  for str in string.gmatch(s, "([^;]+)") do
    table.insert(t, str)
  end
  local ret = {}
  for k,v in pairs(t) do
    local kvpair = {}
    -- THIS IS A NEW CHANGE!
    -- This parses the name of commonmeta metadata
    if k == 1 and hasName then
      -- first element, and it's the name
      ret.recipient = v
    end
    for str in string.gmatch(v, "([^=]+)") do
      table.insert(kvpair, str)
    end
    if #kvpair > 1 then
      -- key value pair
      ret[kvpair[1]] = kvpair[2]
    elseif not hasName then
      ret[#ret+1] = kvpair[1]
    end
  end
  return ret
end

return function(url, privateKey)
  assert(url, "No URL provided")
  assert(privateKey, "No privateKey provided")
  local targetAddresses = {}
  local api = {}

  local ws
  local id = 0

  -- This function can be overwritten
  -- The default one will throw an event when:
  -- The event is a transaction, and is to an address you're interested in
  local function eventHandler(event)
    if event.event == "transaction" then
      event = event.transaction
      local metadata = parseMetadata(event.metadata)
      local returnAddress = metadata["return"] or event.from
      if metadata.recipient then
        -- this is a transaction with a name involved
        local sentAddress = metadata.recipient
        local interested = targetAddresses[sentAddress]
        -- this is an address we're interested in transactions to
        if interested then
          os.queueEvent("krist_transaction", sentAddress, returnAddress, event.value, event)
        end -- if this doesn't execute, then the transaction was to a name we don't care about
      else
        -- this is a transaction without a name involved
        local interested = targetAddresses[event.to]
        -- this is an address we're interested in transactions to
        if interested then
          os.queueEvent("krist_transaction", event.to, returnAddress, event.value, event)
        end -- if this doesn't execute then we're not listening for transactions on this address
      end
    end
  end

  function api.wsReq(T)
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
    local resp = assert(http.post({
      url = url.."/ws/start",
      body = textutils.serialiseJSON({
        privateKey = privateKey
      })
    }), "Error getting websocket URL")
    local code, name = resp.getResponseCode()
    assert(code == 200, "Got bad response, "..code.." "..(name or ""))
    local content = resp.readAll()
    resp.close()
    local body = assert(textutils.unserialiseJSON(content), "Got malformed body")
    return body.url
  end

  local function websocketHandler()
    --[[
      Shield by AlexDevs
      Protect a function from termination by wrapping it.
      Usage: shield(function[, ...args])
      Example: local input = shield(read, "*")
      (c) 2022 AlexDevs
      The MIT License
      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
      THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]

    local expect = require("cc.expect").expect

    local function shield(func, ...)
        expect(1, func, "function")
    
        local thread = coroutine.create(func)
        
        local event, filter, pars = table.pack(...)
        while coroutine.status(thread) ~= "dead" do
            if event[1] ~= "terminate" and filter == nil or filter == event[1] then
                pars = table.pack(coroutine.resume(thread, table.unpack(event, 1, event.n)))
                if pars[1] then
                    filter = pars[2]
                else
                    error(pars[2], 0)
                end
            end
            event = table.pack(coroutine.yield())
        end
    
        return table.unpack(pars, 2)
    end

    api.wsReq({type="subscribe",event="transactions"})
    while true do
      local response = assert(shield(ws.receive), "Websocket dropped")
      response = assert(textutils.unserialiseJSON(response), "Invalid JSON")
      if response.type == "event" then
        eventHandler(response)
      end
    end
  end

  local function connectToWebsocket(wsUrl)
    print("Attempting to connect to websocket...")
    ws = http.websocket(wsUrl)
    print("Connected to websocket!")
  end

  local function stopRedrun()
    local rid = redrun.getid("krist")
    if rid then
      redrun.terminate(rid)
    end
  end

  ---Stop the Krist transaction websocket
  function api.stop()
    stopRedrun()
    if ws then
      ws.close()
      ws = nil
    end
    os.queueEvent("krist_stop", "Stop called")
  end

  local function asyncTask()
    local stat, err = pcall(websocketHandler)
    print("Websocket handler errored!")
    os.queueEvent("krist_stop", err)
    stopRedrun() -- ensure this removes itself from the event handler
    ws.close()
    ws = nil
  end

  local function runAsync()
    stopRedrun()
    redrun.start(asyncTask, "krist")
  end

  ---Start the Krist transaction websocket
  function api.start()
    assert(eventHandler, "No event handler provided")
    connectToWebsocket(getWebsocketUrl())
    runAsync()
  end

  ---Replace the event handler placed in redrun. Advanced users.
  ---@param handler fun(wsEvent:table)
  function api.setEventHandler(handler)
    eventHandler = handler
  end

  --- Subscribe to transactions sent to this address
  function api.subscribeAddress(a)
    targetAddresses[a] = true
  end

  --- Unsubscribe from transactions sent to this address
  function api.unsubscribeAddress(a)
    targetAddresses[a] = nil
  end

  ---Send krist to an address
  ---@param to string Any valid address, or name and metaname.
  ---@param amount integer
  ---@return boolean ok
  ---@return string|nil error
  function api.makeTransaction(to, amount)
    local msg = {
      to = to,
      type = "make_transaction",
      privatekey = privateKey,
      amount = amount
    }
    local status = api.wsReq(msg)
    return status.ok, status["error"]
  end

  ---Websocket
  api.ws = ws
  api.parseMetadata = parseMetadata

  return api

end