local plugin = { PRIORITY = 1012, VERSION = "0.1", }               -- Set Plugin Version & Execution Priority

-- Lua Imports
local kong     = kong
local lrucache = require "resty.lrucache"                          -- to introduce LRU lua memory caching
local cjson    = require("cjson.safe").new()
local http     = require "resty.http"

-- Global Variables
local logINFO = kong.log.info
local logDBG  = kong.log.debug
local logERR  = kong.log.err
local scopes

-- Initialize Local Cache
local lru, err = lrucache.new(1000)                                -- Set Cache
if not lru or err then                                             -- Abort if Cache Init Error
  logERR("Cache initialization error! " .. (err or "unknown"))
end

function plugin:access(plugin_conf)

  -- Plugin Configuration Variables
  local ttl              = plugin_conf.ttl                         -- Cache TTL in seconds
  local ssl_verify       = plugin_conf.ssl_verify                  -- SSL Verification boolean
  local scopes_api       = plugin_conf.scopes_api                  -- Scopes API Endpoint variable
  local scopes_header    = plugin_conf.scopes_header               -- Scopes Header Name variable
  local client_id_header = plugin_conf.client_id_header            -- ID Header name variable

  -- Set Error Messages
  local error_msg_400 = "400 ERROR Client ID Header sent with nil value!"
  local error_msg_500 = "500 ERROR Failure calling Scopes API!"

  -- Scopes API Query Function
  local function get_scopes(client_id)
    logDBG("Scopes API URL: ", scopes_api)
    local httpc    = http.new()                                    -- Set HTTP connection
    local res, err = httpc:request_uri(scopes_api, {               -- Request Scopes API
      method = "POST",
      ssl_verify = ssl_verify,
      headers = {
        [client_id_header] = client_id,                            -- Send Client ID to Scopes API
        ["Content-Type"] = "application/x-www-form-urlencoded",
      }
    })
    logDBG("Scopes API Response Body: ", res.body)
    if (not res) or err then                                       -- Test if Scopes API request was successful
      logINFO(error_msg_500, err)                                  -- log 500 if Scopes API request failed & log error
      return kong.response.exit(500, { message = error_msg_500, }) -- Return 500 if Scopes API request failed & log error
    else
      scopes = cjson.decode(res.body).scopes                       -- Decode Scopes from JSON response
    end
    return scopes
  end

  local client_id = kong.request.get_header(                       -- Lookup Client ID from request header
    plugin_conf.client_id_header
  )

  if client_id_header and client_id == nil then                    -- Test if ID Header is sent with NILL value
    logERR(error_msg_400)                                          -- Log Error
    return kong.response.exit(400, { message = error_msg_400 })    -- Return HTTP 400 Bad Request
  end

  if client_id_header then                                         -- Append scopes to headers if Client ID Header present
    logDBG(client_id_header, ": ", client_id)

    local cache_hit = lru:get(client_id)                           -- Search for Client ID in Cache
    if cache_hit then                                              -- Test if Client ID was found in Cache
      logINFO("Cache Hit: ", client_id)                            -- Log Cache Hit
      logDBG(                                                      -- Debug Log: Client ID, Scopes, Headers
        "Cache Data: ",
        client_id,
        cjson.encode(cache_hit)
      )
      -- TODO: append cached scopes to headers
    else
      logINFO("Cache Miss: ", client_id)                           -- Log cache miss for Client ID
      local scope_res = get_scopes(client_id)                      -- If cache miss, query Scopes API
      if scope_res then
        lru:set(client_id, scope_res, ttl)
      end
      for i,scope in ipairs(scope_res) do                          -- Append each scopee as a header
        kong.service.request.add_header(scopes_header, scope)
        logINFO(client_id,
          " add scope: [", scopes_header, ": ", scope, "]"
        )
      end
    end
  else                                                             -- Allow request to continue if Client ID Header is not present
    logDBG("Id Header not detected. Skip rolescope query.")
  end
  logDBG(
    "Client ID ", client_id, " - ",
    "Scopes JSON: ", cjson.encode(scopes),
    "All Headers: ", client_id, ": ", cjson.encode(
      kong.request.get_headers()
    )
  )
end

return plugin                                                      -- return our plugin object
