local plugin = { PRIORITY = 1012, VERSION = "0.1", }        -- Set Plugin Version & Execution Priority

-- Lua Imports
local kong = kong
local http = require "resty.http"
local cjson = require("cjson.safe").new()

function plugin:access(plugin_conf)

  kong.log.inspect(plugin_conf)                             -- Load Plugin Configuration

  local httpc = http.new()                                  -- Set HTTP connection
  local ssl_verify = plugin_conf.ssl_verify                 -- SSL Verification boolean
  local scopes_api = plugin_conf.scopes_api                 -- Scopes API Endpoint variable
  local scopes_header = plugin_conf.scopes_header           -- Scopes Header Name variable
  local client_id_header = plugin_conf.client_id_header     -- ID Header name variable

  kong.log.debug("Scopes API URL: ", scopes_api)

  if not client_id_header then                              -- Allow request to continue if Client ID Header is not present
    kong.log.debug("Id Header not detected .. skip rolescope query ..")

  else                                                      -- If Client ID Header is present, append rolescopes to headers
    if client_id_header == nil then                         -- If ID Header is not set
      kong.log.err("ERR 400 Client ID Header not set")      -- Log error
      return kong.response.exit(400, {                      -- Return HTTP 400 Bad Request
        message = "Client ID Header not set"
      })

    end

    local client_id = kong.request.get_header(              -- Set Client ID variable from Client ID Header
      plugin_conf.client_id_header
    )

    kong.log.debug(
      "Client ID Header: ", client_id_header, " - ",
      "Client ID: ",        client_id
    )

    local res, err = httpc:request_uri(scopes_api, {        -- Request Scopes API
      method = "POST",
      ssl_verify = ssl_verify,
      headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        [client_id_header] = client_id,                     -- Send Client ID to Scopes API
      }
    })

    kong.log.debug("Scopes API Response Body: ", res.body)

    -- Test if Scopes API request was successful
    if (not res) or err then
      kong.log.err("Scopes API Failure: ", err)             -- Return 500 if Scopes API request failed & log error
      return kong.response.exit(500, { message = "Error calling Scopes API endpoint" })

    else

      local scopes = cjson.decode(res.body).scopes          -- Decode Scopes from JSON response

      kong.log.debug(
        "Client ID ", client_id, " - ",
        "Scopes JSON: ", cjson.encode(scopes)
      )

      for i,scope in ipairs(scopes) do                      -- Append each scopee as a header
        kong.service.request.add_header(scopes_header, scope)
        kong.log.debug("Add Header: [", scopes_header, ": ", scope, "]")
      end

      kong.log.info(client_id_header, ": ", cjson.encode(kong.request.get_headers()))

    end
  end
end

return plugin                                               -- return our plugin object
