-- Import libraries
local kong = kong
local http = require "resty.http"
local cjson = require("cjson.safe").new()
-- local sharedCache = ngx.shared.kong_dynamic_endpoint


local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

function plugin:init_worker()
  -- kong.log.debug("Uplight rolescopes plugin") -- idk why this was breaking plugin execution
end

function plugin:access(plugin_conf)

  kong.log.inspect(plugin_conf)   -- check the logs for a pretty-printed config!

  -- assign uplight id header value to variable
  local idHeader = kong.request.get_header(plugin_conf.uplight_id)

  -- if uplight_id header is present, request rolescopes and add scopes to headers
  if not idHeader then
    kong.log.debug("Uplight id header not found, exiting rolescope lookup")
  else
    kong.log.debug("Uplight id header detected, attempting rolescope lookup")

    -- construct request url
    local url = plugin_conf.role_scopes_endpoint
    kong.log.info("roleScopes URL:", url)

    -- query rolescopes endpoint
    local httpc = http.new()
    local roleScopeResponse, err = httpc:request_uri(url, {
    method = "POST",
    -- example body
    -- body = what_you_are_sending,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded"
    },
    keepalive_timeout = 60,
    keepalive_pool = 10,
    --[[ ssl_verify should really be true ]]
    ssl_verify= false
    })

    if (not roleScopeResponse) or err then
      kong.log.err("Error querying rolescopes endpoint: ", err)
      return kong.response.exit(500, { message = "Error querying rolescopes endpoint: " .. err })
    else
      local responseJson = cjson.encode(roleScopeResponse.body.role)
      -- local roles = responseJson["role"]
      -- local accountId = roles["accountId"]
      -- kong.log.info("Role: ", roles, " Account ID: ", accountId)

      kong.log.info("Uplight rolescopes plugin: ", responseJson)

      -- add scope to headers
      local header = "X-Uplight-roleScopes"
      -- kong.service.request.set_header(header, scope)
      -- kong.log.info("Uplight rolescopes plugin: ", header, " set to: ", scope)

    end

    -- kong.service.request.set_header("X-Account-Id", jsonResponse.role.accountId)
    -- kong.service.request.set_header("X-Party-Id", jsonResponse.role.partyId)


--[[
    -- for i,scope in ipairs(jsonResponse.scopes) do
    --   kong.service.request.add_header("X-Uplight-RoleScope", scope)
    -- end
--]]
  end

end


--[[ runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]


-- return our plugin object
return plugin
