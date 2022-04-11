-- Import libraries
local kong = kong
local httpc = require "resty.http"
local cjson = require "cjson"
-- local sharedCache = ngx.shared.kong_dynamic_endpoint


local plugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

function plugin:init_worker()
  kong.log.debug("Uplight rolescopes plugin")
end

function plugin:access(plugin_conf)

  kong.log.inspect(plugin_conf)   -- check the logs for a pretty-printed config!

--[[
--]]

  -- assign uplight id header value to variable
  local idHeader = kong.request.get_header(plugin_conf.uplight_id)

  -- if uplight_id header is present, request rolescopes and add scopes to headers
  if not idHeader then
    kong.log.debug("Uplight id header not found, exiting rolescope lookup")
  else
    kong.log.debug("Uplight id header detected, attempting rolescope lookup")

    local roleScopeResponse, err = httpc:request_uri(plugin_conf.role_scopes_endpoint, { method = "GET", query = string.format("uplightId=%s", idHeader) })
    local jsonResponse = cjson.decode(roleScopeResponse)
    kong.service.request.set_header("X-Account-Id", jsonResponse.role.accountId)
    kong.service.request.set_header("X-Party-Id", jsonResponse.role.partyId)

    for i,scope in ipairs(jsonResponse.scopes) do
      kong.service.request.add_header("X-Uplight-RoleScope", scope)
    end
  end

end


--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'body_filter' handler")

end --]]


--[[ runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'log' handler")

end --]]


-- return our plugin object
return plugin
