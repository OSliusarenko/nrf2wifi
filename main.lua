nrf = require("nrf24l01")

nrf.init(85, "rx") --start listening
print ("listening started")
secwaited = 0
tmr.alarm(0, 1000, tmr.ALARM_AUTO, function() --query each 1 sec for received data
        local tmp = nrf.wait()
        if (type(tmp)=="table") then --we received data!
            if (tmp[1]==0x10 and tmp[2]==0xff) then
                local http_params = {}
                tmr.unregister(0)
                http_params.time = rtctime.get()
                nrf.down()
                http_params.batt = (bit.band(bit.lshift(tmp[7],8),0xff00)+tmp[8])*50/1023-1
                http_params.temp = (bit.band(bit.lshift(tmp[5],8),0xff00)+tmp[6])*15000/3632-2670
                print("t = " .. http_params.temp)
                http.post('http://json.example.com/something',
                    'Content-Type: application/json\r\n',
                    cjson.encode(http_params),
                    function(code, data)
                        if (code < 0) then
                            print("HTTP request failed")
                        else
                            print(code, data)
                        end
                        tmr.delay(1000) --remove this
                        local tm = rtctime.get()
                        rtctime.dsleep((590-(tm-http_params.time))*1000000, 2)
                    end
                )
            else
                print ("Strange data received!")
            end
        end
    end
)





