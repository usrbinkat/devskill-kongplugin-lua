local typedefs = require "kong.db.schema.typedefs"

local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          {
            uplight_id = {
              type = "string",
              required = false,
              default = "X-Uplight-Id",
            }
          },
          {
            role_scopes_endpoint = {
              type = "string",
              required = true,
            }
          },
          {
            ttl = {
              type = "integer",
              required = true,
              default = 600,
              gt = 0, -- must be greater than 0
            }
          },
        },
        entity_checks = {
          -- add some validation rules across fields
          -- the following is silly because it is always true, since they are both required
          { at_least_one_of = { "uplight_id", "role_scopes_endpoint" }, },
          -- We specify that both header-names cannot be the same
          { distinct = { "uplight_id", "role_scopes_endpoint"} },
        },
      },
    },
  },
}

return schema
