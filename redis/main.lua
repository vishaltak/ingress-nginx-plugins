local ngx = ngx

local _M = {}

function _M.rewrite()
    local redis = require "resty.redis"
    local http = require "resty.http"
    local red = redis:new()
    local httpc = http.new()
    local ok, err = red:connect("127.0.0.1", 6379)
    red:set_timeouts(1000, 1000, 1000)
    local host = ngx.var.host;
    local key = "maintanance_domains:" .. host
    local data = ngx.shared.configuration_data:get(key)
    ngx.log(ngx.ERR,data)
    if not data or data == ngx.nill then
        local result, err = red:hget("maintanance_domains",host)
        if result then
            data = result
            ngx.shared.configuration_data:set(key, result, 300);
        else
            ngx.shared.configuration_data:set(key,false,300);
        end
    end
    if data == "true" then
        local res, err = httpc:request_uri("<your maintaince static url>")
        ngx.say(res.body);
    else
    end



end

return _M