--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

-- Set module name as parameter of require
local modname = ...
local M = {}
_G[modname] = M
--------------------------------------------------------------------------------
-- Local used variables
--------------------------------------------------------------------------------
-- Hardware SPI CLK  = 5 GPIO14
-- Hardware SPI MOSI = 7 GPIO13
-- Hardware SPI MISO = 6 GPIO12
local ce = 3
local csn = 8 -- GPIO15, pull-down 10k to GND
local defaultRX = true
local ack_pw = 255
--------------------------------------------------------------------------------
-- Local used modules
--------------------------------------------------------------------------------
-- GPIO module
local gpio = gpio
-- spi module
local spi = spi
-- bit module
local bit = bit
-- Timer module
local tmr = tmr
local print = print --remove this
-- Limited to local environment
setfenv(1,M)
--------------------------------------------------------------------------------
-- Implementation
--------------------------------------------------------------------------------
function CE_LOW()
    tmr.delay(5000)
    gpio.write(ce, gpio.LOW)
    tmr.delay(5000)
end

function CE_HIGH()
    tmr.delay(5000)
    gpio.write(ce, gpio.HIGH)
    tmr.delay(5000)
end

function CSN_LOW()
    tmr.delay(5000)
    gpio.write(csn, gpio.LOW)
    tmr.delay(5000)
end

function CSN_HIGH()
    tmr.delay(5000)
    gpio.write(csn, gpio.HIGH)
    tmr.delay(5000)
end

function WRreg(addr, data)
    CSN_LOW()
    tmr.delay(5000)
    spi.send(1, bit.bor(0x20, bit.band(0x1f, addr)))
    tmr.delay(5000)
    spi.send(1, data)
    tmr.delay(5000)
    CSN_HIGH()
end

function RDreg(addr)
    local a, b
    CSN_LOW()
    tmr.delay(5000)
    spi.send(1, bit.bor(0x00, bit.band(0x1f, addr)))
    tmr.delay(5000)
    a, b = spi.send(1, 0xff) -- NOP
    tmr.delay(5000)
    CSN_HIGH()

    return a, b
end

function init(channel, default_mode)
    if (default_mode=="rx") then defaultRX=true else defaultRX=false end
    spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 800, spi.FULLDUPLEX)

    gpio.mode(ce, gpio.OUTPUT)
    gpio.mode(csn, gpio.OUTPUT)

    CE_LOW()
    CSN_HIGH()

    WRreg(0x01, 0x3f)
    WRreg(0x02, 0x03)
    WRreg(0x03, 0x03)
    WRreg(0x04, 0x3f)
    WRreg(0x05, channel)

    WRreg(0x06, 0x07) -- 1Mbps max pwr hi-gain LNA
    WRreg(0x0a, {0xe7,0xe7,0xe7,0xe7,0xe7})
    WRreg(0x0b, {0xc2,0xc2,0xc2,0xc2,0xc2})
    WRreg(0x0c, 0xc3)
    WRreg(0x0d, 0xc4)
    WRreg(0x0e, 0xc5)
    WRreg(0x0f, 0xc6)
    WRreg(0x10, {0xe7,0xe7,0xe7,0xe7,0xe7})
    WRreg(0x11, 8)
    WRreg(0x12, 8)
    WRreg(0x13, 0)
    WRreg(0x14, 0)
    WRreg(0x15, 0)
    WRreg(0x16, 0)
    WRreg(0x1d, 0x06)
    WRreg(0x1c, 0x3f)

    --power up
    local data = 0xe
    if (defaultRX) then
        data = bit.bor(data, 0x01)  -- default rx or tx
    end

    WRreg(0x00, data)

    if (defaultRX) then
        CE_HIGH()
    else
        CE_LOW()
    end

end

function irq_clear_all()
    WRreg(0x07, 0x70)
end

function flush_rx()
    CSN_LOW()
    tmr.delay(5000)
    spi.send(1, 0xe2)
    tmr.delay(5000)
    CSN_HIGH()
end

function flush_tx()
    CSN_LOW()
    tmr.delay(5000)
    spi.send(1, 0xe1)
    tmr.delay(5000)
    CSN_HIGH()
end

function status()
    local a, status
    CSN_LOW()
    tmr.delay(5000)
    a, status = spi.send(1, 0x00)
    tmr.delay(5000)
    CSN_HIGH()
    return status
end

function down()
    local a, conf
    irq_clear_all()
    flush_tx()
    flush_rx()
    a, conf = RDreg(0x00)
    conf = bit.band(conf, bit.bnot(0x02)) -- pwr dn
    WRreg(0x00, conf)
    CE_LOW()
end

function cmd(cmd, data)
    local a, rx
    CSN_LOW()
    tmr.delay(5000)
    spi.send(1, cmd)
    tmr.delay(5000)
    a, rx = spi.send(1, data)
    tmr.delay(5000)
    CSN_HIGH()
    tmr.delay(1000)
    return rx
end

function transmit(data)
    local a, rx
    rx = cmd(0xa0, data)
    CE_HIGH()
    tmr.delay(30)
    CE_LOW()
    return rx
end

function readRX(pw)
    local tx = {}
    local rx = {}
    for i=1, pw do tx[i] = 0 end
    CE_LOW()
    rx = cmd(0x61, tx)
    CE_HIGH()
    return rx
end

function wait()
    local tmp=status()
    local rx

    if(bit.band(tmp, 0x40)~=0) then -- rx_dr
        ack_pw = cmd(0x60, 0xff) -- get dyn payload width
        print ("ACK pw = ", ack_pw) --remove this
        rx = readRX(ack_pw)
        flush_rx()
        irq_clear_all()
        return rx
    end
    if(bit.band(tmp, 0x20)~=0) then -- tx_ds
        flush_tx()
        irq_clear_all()
        return 1
    end
    if(bit.band(tmp, 0x10)~=0) then -- max_rt
        flush_tx()
        flush_rx()
        irq_clear_all()
        return -1
    end
    return 2
end



-- Return module table
return M
