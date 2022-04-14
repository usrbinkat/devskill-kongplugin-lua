-- Inherit plugin name
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
          -- Define configurable fields
          {
            -- Header name to set the Uplight ID
            client_id_header = {
              type = "string",
              default = "X-Uplight-Id",
              required = true,
            }
          },
          {
            -- Header name to add the rolescopes to
            scopes_header = {
              type = "string",
              default = "X-Uplight-roleScopes",
              required = true,
            }
          },
          {
            -- URL to query for rolescopes
            scopes_api = {
              type = "string",
              required = true,
            }
          },
          {
            -- URL to query for rolescopes
            ssl_verify = {
              type = "boolean",
              required = true,
              default = false,
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
        -- Declare sanity checks
        entity_checks = {
          {
            -- Validate required fields are set
            at_least_one_of = {
              "client_id_header",
              "scopes_header"
            },
          },
          {
            -- Validate header-names can not be the same
            distinct = {
              "client_id_header",
              "scopes_header"
            }
          },
        },
      },
    },
  },
}

return schema
