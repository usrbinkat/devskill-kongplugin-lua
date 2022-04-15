--[[
  This plugin is designed to augment IDP provided role scopes via secondary scopes api service
  to append acquired additional scopes to the request *if* a specified header is populated with a Client ID.

  Generically, the logic follows thus:
    - If the named header is not present and populated then ignore and allow request to proceed normally
    - If the named header is present with a Client ID value, then obtain and append the additional scopes as headers
      - First query local cache for cached results
      - Second, if cache query is a miss than proceed to query scopes provider api
        - If the scopes api returns an error then return the error to the client
        - If the scopes api returns an error than return 500 to the client
        - If the scopes api returns scopes successfully then:
          - Cache the scope results by Client ID with the configured ttl value
          - Return the scopes to the next handler
      - Finally, append the additional scopes to the request as additional headers

  Logging includes the following logs per log level:
    INFO:
      - when a Cache hit occurs
      - when a Cache miss occurs
      - when scopes are added to a request
      - when a 500 is returned to the client
    DEBUG:
      - Scopes JSON
      - Scopes API URL
      - Cache hit return data
      - Scopes api response body
      - Log when no Client ID is found
      - All headers after plugin is run
      - Client ID Header key name and value
--]]

local plugin = { PRIORITY = 1012, VERSION = "1.0", }               -- Set Plugin Version & Execution Priority

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
-- Set Error Messages
local error_msg_400 = "400 ERROR Client ID Header sent with nil value!"
local error_msg_500 = "500 ERROR Failure calling Scopes API!"

-- Initialize Local Cache
local lru, err = lrucache.new(1000)                                -- Set Cache
if not lru or err then                                             -- Abort if Cache Init Error
  logERR("Cache initialization error! " .. (err or "unknown"))
end

function plugin:access(plugin_conf)                                -- Core Function
  -- Plugin Configuration Variables
  local ttl              = plugin_conf.ttl                         -- Cache TTL in seconds
  local ssl_verify       = plugin_conf.ssl_verify                  -- SSL Verification boolean
  local scopes_api       = plugin_conf.scopes_api                  -- Scopes API Endpoint variable
  local scopes_header    = plugin_conf.scopes_header               -- Scopes Header Name variable
  local client_id_header = plugin_conf.client_id_header            -- ID Header name variable

  -- Scopes API Query Function
  local function get_scopes(client_id)
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

  if (client_id == nil) then                                       -- Append scopes to headers if Client ID Header present
    logDBG("No Client ID Found")
  else
    logDBG(client_id_header, ": ", client_id)

    local cache_hit = lru:get(client_id)                           -- Search for Client ID in Cache
    if cache_hit then                                              -- Test if Client ID was found in Cache
      logINFO("Cache Hit: ", client_id)                            -- Log Cache Hit
      logDBG(                                                      -- Debug Log: Client ID, Scopes, Headers
        "Cache Data: ",
        client_id, " ",
        cjson.encode(cache_hit)
      )
    else
      logINFO("Cache Miss: ", client_id)                           -- Log cache miss for Client ID
      local scope_res = get_scopes(client_id)                      -- If cache miss, query Scopes API
      if scope_res then
        lru:set(client_id, scope_res, ttl)
      end
    end

    -- Add scopes to headers
    for i,scope in ipairs(scopes) do                               -- Append each scopee as a header
      kong.service.request.add_header(scopes_header, scope)
      logINFO(client_id,
        " add scope: [", scopes_header, ": ", scope, "]"
      )
    end

    logDBG("Scopes API URL: ", scopes_api)
    logDBG("Scopes JSON: ", cjson.encode(scopes))
    logDBG("All Headers: ", client_id, ": ", cjson.encode(kong.request.get_headers()))
  end
end

return plugin