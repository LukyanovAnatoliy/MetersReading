print("Start water accounting");

-- настройка GPIO
gpio.mode(COLD_GPIO, gpio.INPUT, gpio.PULLUP);
gpio.mode(HOT_GPIO, gpio.INPUT, gpio.PULLUP);

-- подключаемся к wifi точке 
setup_wifi_as_station()

cold_state = 0;
hot_state = 0;
--каждую секунду проверяем состояние выходов
tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()

    invert_led();

    -- холодная вода
    if ((gpio.read(COLD_GPIO) == 0) and (cold_state == 1)) then
        cold_values.inc = cold_values.inc + INC_VALUE;
        cold_values.total = cold_values.total + INC_VALUE;
        write_to_file(FILE_COLD, cold_values);
    end;
    cold_state = gpio.read(COLD_GPIO);

    -- горячая вода
    if ((gpio.read(HOT_GPIO) == 0) and (hot_state == 1)) then
        hot_values.inc = hot_values.inc + INC_VALUE;
        hot_values.total = hot_values.total + INC_VALUE;
        write_to_file(FILE_HOT, hot_values);
    end;
    hot_state = gpio.read(HOT_GPIO);

end)

-- каждую минуту отправляем данные
tmr.alarm(2, 60000, tmr.ALARM_AUTO, function()
    if (wifi.sta.status() == wifi.STA_FAIL ) then
        setup_wifi();
        return;
    end;
    -- если нет подключения, выходим
    if (wifi.sta.status() ~= wifi.STA_GOTIP) then
        return;
    end;
    -- отправляем данные если произошли какие-либо изменения 
    if (tonumber(cold_values.inc) > 0) or (tonumber(hot_values.inc) > 0) then
        conn = net.createConnection(net.TCP, 0)
        conn:on("receive", function(con, receive)
        
            cold_values.inc = 0;
            write_to_file(FILE_COLD, cold_values);

            hot_values.inc = 0;
            write_to_file(FILE_HOT, hot_values);

            con:close();
        
        end)
        conn:on("connection", function(c)
            local param_str = "";
            if (tonumber(cold_values.inc) > 0) then
                param_str = "&"..settings[PARAM_COLD_FIELD_INC].."="..tostring(cold_values.inc).."&"..
                                 settings[PARAM_COLD_FIELD_TOTAL].."="..tostring(cold_values.total);
            end;
            if (tonumber(hot_values.inc) > 0) then
                param_str = param_str.."&"..
                            settings[PARAM_HOT_FIELD_INC].."="..tostring(hot_values.inc).."&"..
                            settings[PARAM_HOT_FIELD_TOTAL].."="..tostring(hot_values.total);
            end;

            c:send("GET /update?key="..settings[PARAM_API_KEY]..param_str
                .." HTTP/1.1\r\n"
                .."Host: api.thingspeak.com\r\n"
                .."Connection: keep-alive\r\n"
                .."Accept: */*\r\n"
                .."\r\n");
        end)
        conn:connect(80,"api.thingspeak.com");
    end;
end)
