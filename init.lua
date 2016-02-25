function onConnectSuccess()
    tmr.unregister(1)
    print("Device IP: " .. wifi.sta.getip())
    wifi.sta.eventMonStop()
    wifi.sta.eventMonReg(wifi.STA_GOTIP, "unreg")
    sntp.sync('ua.pool.ntp.org',
      function(sec,usec,server)
        print('Time sync:', sec, server) -- sync success
        dofile('main.lua')
      end,
      function()
       print('Time sync failed!')
      end
    )
end

function onConnectFailure()
    print('Unable to connect to WiFi')
    wifi.sta.eventMonStop()
    wifi.sta.eventMonReg(wifi.STA_GOTIP, "unreg")
end

function connectWifi()
    wifi.setmode(wifi.STATION)
    print('MAC: ',wifi.sta.getmac())
    print('chip: ',node.chipid())
    print('heap: ',node.heap())
    wifi.sta.config("", "")
    tmr.alarm(1,30000,0, function() onConnectFailure() end)
    wifi.sta.eventMonReg(wifi.STA_GOTIP, function() onConnectSuccess() end)
    wifi.sta.eventMonStart()
end

function disconnectWifi()
    wifi.sta.disconnect()
end

function go()
    --check whether time is set
    if (rtctime.get()==0) then
        connectWifi() --connect to WiFi, sync time and do 'main.lua'
    else
        dofile("main.lua") --everything's already setup, just continue
    end
end

dofile("startscript.lua")
