local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

--[[
  GET 'https://platform.uplight.io/api/v1/bills' \
  --header 'Authorization: Bearer MKWauvpcTyTizgkAs9ITE7wkemNA' \ <- from google
  --header 'X-Uplight-Id: e8d6c0dc-713a-4e67-a74a-39b9ac5f4787'

  GET 'https://digitalaccount.uplight.io/v1/roleScopes?uplightId=fe835f8c-843c-44a5-8abd-ad997585bb84' \
--]]

local schema = {
  name = plugin_name,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
        type = "record",
        fields = {
          -- uplight id
          -- uplight token
          -- client id
          { uplight_id = {
              type = "string",
              required = false,
              default = "X-Uplight-Id" } },
          { role_scopes_endpoint = {
              type = "string",
              default = "https://digitalaccount.uplight.io/v1/roleScopes",
              required = true, } },
          { ttl = {
              type = "integer",
              default = 600,
              required = true,
              gt = 0, }}, -- adding a constraint for the value
        },
        entity_checks = {
          -- add some validation rules across fields
          -- the following is silly because it is always true, since they are both required
          { at_least_one_of = { "request_header", "response_header" }, },
          -- We specify that both header-names cannot be the same
          { distinct = { "request_header", "response_header"} },
        },
      },
    },
  },
}

return schema
