print("Start setup mode");

wifi.setmode(wifi.SOFTAP);

-- настройка точки доступа
local cfg={};
cfg.ssid="ESP_"..node.chipid();
cfg.pwd="1234567890";
cfg.hidden=0;
cfg.auth=wifi.AUTH_OPEN;
wifi.ap.config(cfg);

local ip_cfg = {};
ip_cfg.ip="1.1.1.1"
wifi.ap.setip(ip_cfg);

local isredirected = 0;

local function sender(conn)
    if (isredirected == 1) then
        conn:close();
    else
        local line = file.readline();
        if (line) then
            conn:send(line);
        else
            file.close();
            conn:close();
        end;
    end;
end;

local function onReceive(conn,request)
        if (request == nil) or (request == "") then
            return;
        end;
        _, _, method, path, vars = string.find(request, "([A-Z]+) (.*)/%??(.*) HTTP");
        if (method == "GET") then
            if (vars == nil) or (vars == "") then
                isredirected = 1;
                conn:send('<script type="text/javascript"> document.location.href="http://1.1.1.1/?'..
                        PARAM_SSID..'='..settings[PARAM_SSID]..'&'..
                        PARAM_PASSWORD..'='..settings[PARAM_PASSWORD]..'&'..
                        PARAM_API_KEY..'='..settings[PARAM_API_KEY]..'&'..

                        PARAM_COLD_FIELD_INC..'='..settings[PARAM_COLD_FIELD_INC]..'&'..
                        PARAM_COLD_FIELD_TOTAL..'='..settings[PARAM_COLD_FIELD_TOTAL]..'&'..
                        PARAM_COLD_VALUE..'='..cold_values.total..'&'..

                        PARAM_HOT_FIELD_INC..'='..settings[PARAM_HOT_FIELD_INC]..'&'..
                        PARAM_HOT_FIELD_TOTAL..'='..settings[PARAM_HOT_FIELD_TOTAL]..'&'..
                        PARAM_HOT_VALUE..'='..hot_values.total..'&'..

                        PARAM_POWER_FIELD_INC..'='..settings[PARAM_POWER_FIELD_INC]..'&'..
                        PARAM_POWER_FIELD_TOTAL..'='..settings[PARAM_POWER_FIELD_TOTAL]..'&'..
                        PARAM_POWER_VALUE..'='..power_values.total..'&'..
                        PARAM_POWER_FIELD_CURRENT_CONS..'='..settings[PARAM_POWER_FIELD_CURRENT_CONS]..'&'..
                        PARAM_POWER_FIELD_MAX_VALUE..'='..settings[PARAM_POWER_FIELD_MAX_VALUE]..'&'..

                        PARAM_TYPE_ACCOUNTING..'='..settings[PARAM_TYPE_ACCOUNTING]..'&'..
                        PARAM_COUNT_IMPULS_IN_KW..'='..settings[PARAM_COUNT_IMPULS_IN_KW]..
                        '"; </script>');
            else
                if (string.match(vars, "([%w_]+)=([%w_]*)")) then
                    file.open("index.html", "r");
                    isredirected = 0;
                    sender(conn);
                else
                    conn:close();
                end;
            end;
        else
            -- в post запросе новые данные передаются вконце
            -- необходимо их вытащить
            start, _, _ = string.find(request, "\n[%w_]+=%w*");
            param = string.sub(request, start + 1);
            cold_values.inc = 0;
            hot_values.inc = 0;
            power_values.inc = 0;
            for k, v in string.gmatch(param, "([%w_]+)=(%w*)") do
                print(k, v);
                if (k == PARAM_COLD_VALUE) then
                    cold_values.total = tonumber(v);
                else if (k == PARAM_HOT_VALUE) then
                        hot_values.total = tonumber(v);
                    else if (k == PARAM_POWER_VALUE) then
                            power_values.total = tonumber(v);
                        else
                            settings[k] = v;
                        end;
                    end;
                end;
            end;
            write_to_file(FILE_MAIN_PARAMETERS, settings);
            write_to_file(FILE_COLD, cold_values);
            write_to_file(FILE_HOT, hot_values);
            write_to_file(FILE_POWER, power_values);
            node.restart();
        end;
    end

-- запуск сервера
srv=net.createServer(net.TCP);
srv:listen(80, function(conn)
    conn:on("receive", onReceive);
    conn:on("sent", sender);
    conn:on("connection", function(sck, c)
        tmr.unregister(0);
    end)
end)

-- запускаем таймер на отключение режима настройки
-- отключаем режим настройки через 60 секунд
tmr.alarm(0, 60000, tmr.ALARM_SINGLE, function()

    print("execute stop setup mode");
    
    if (settings[PARAM_SSID] ~= nil) and (settings[PARAM_SSID] ~= "") and
        (settings[PARAM_PASSWORD] ~= nil) and (settings[PARAM_PASSWORD] ~= "") then
        
        srv:close();

        if (settings[PARAM_TYPE_ACCOUNTING] == nil) or 
            (settings[PARAM_TYPE_ACCOUNTING] == TYPE_WATER_METER) then

            dofile("water_mode.lua");

        else
            dofile("power_mode.lua");
        end;
    else
        showError();
   end;

end)
