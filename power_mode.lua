print("Start power accounting");

-- подключаемся к wifi точке 
setup_wifi_as_station()

local MAX_INT = 2147483647;
local MICRO_W = 100000;

-- настройка GPIO
gpio.mode(POWER_GPIO, gpio.INPUT, gpio.PULLUP)

-- если не задано кол-во импульсов на кВт*ч, то это ошибка
if (settings[PARAM_COUNT_IMPULS_IN_KW] == nill) or
    (settings[PARAM_COUNT_IMPULS_IN_KW] == "") then

    showError();
    return;

end;

local count_imp_in_kW = settings[PARAM_COUNT_IMPULS_IN_KW];
local min_count_imp_for_inc_total = count_imp_in_kW / 200; -- инкримируем итоговое значением минимум на 0.5%
local value_for_inc_total = 1000 / 200; -- инкримируем итоговое значением минимум на 0.5% => 5Вт*ч
local value_for_inc_current_cons = 1000 * MICRO_W / count_imp_in_kW; -- 1кВт*ч / count_imp_in_kW

local current_cons = 0;
local max_value = 0;
local last_imp_time = tmr.now();
local prev_trig_time = tmr.now();
local prev_diff_time = 0;

local count_tick = 0;

local prev_state = 0;
-- функция проверки состояния выводов и инкрементации показаний
local function check_power_input_state()

    trig_time = tmr.now();

    -- при переполнении счетчика прошедшего времени с момента запуска устройства
    -- отсчет начинается с нуля
    if (trig_time > prev_trig_time) then
        diff_time = trig_time - prev_trig_time;
    else
        diff_time = trig_time  + (MAX_INT - prev_trig_time);
    end;

    if (gpio.read(POWER_GPIO) == 1 and prev_state == 0) then

        prev_trig_time = trig_time;

        if (trig_time > last_imp_time) then
            duration = (trig_time - last_imp_time) / 1000;
        else
            duration = (trig_time + (MAX_INT - last_imp_time)) / 1000;
        end
        
        if (duration == 0) then
            return;
        end;
        last_imp_time = trig_time;

        current_cons = (1000 * (3600000 / count_imp_in_kW)) / duration;
        if current_cons > max_value then
            max_value = current_cons;
        end;

        count_tick = count_tick + 1;
        power_values.inc = power_values.inc + value_for_inc_current_cons;
        if (count_tick == min_count_imp_for_inc_total) then
            power_values.total = power_values.total + value_for_inc_total; 
            count_tick = 0;
            write_to_file(FILE_POWER, power_values);
        end;

        prev_state = 0;
        invert_led();
        
    end;
    prev_state = gpio.read(POWER_GPIO);
end;

-- каждые 10 мс проверяем состояние выводов
tmr.alarm(2, 10, tmr.ALARM_AUTO, check_power_input_state)

-- функция отправки данных на сервер
local function send_power_to_server()
    print("Try send power");
    print("power_values", table_to_str(power_values), "max_value", max_value);

    -- если нет подключения, выходим
    if (wifi.sta.status() ~= wifi.STA_GOTIP) then
        return;
    end;

    local inc_value = power_values.inc / MICRO_W;
    power_values.inc = power_values.inc - inc_value * MICRO_W;
    write_to_file(FILE_POWER, power_values);

    local s_max_value = max_value;
    max_value = 0;
    local s_current_cons = current_cons;
    current_cons = 0;
    
    -- отправка данных
    conn = net.createConnection(net.TCP, 0)
    conn:on("receive", function(con, receive)

        --print(receive);
        con:close();
    
    end)
    conn:on("connection", function(c)
        local param_str = "";
        param_str = "&"..settings[PARAM_POWER_FIELD_INC].."="..tostring(inc_value).."&"..
                         settings[PARAM_POWER_FIELD_TOTAL].."="..tostring(power_values.total).."&"..
                         settings[PARAM_POWER_FIELD_CURRENT_CONS].."="..tostring(s_current_cons).."&"..
                         settings[PARAM_POWER_FIELD_MAX_VALUE].."="..tostring(s_max_value);
        
        c:send("GET /update?key="..settings[PARAM_API_KEY]..param_str
            .." HTTP/1.1\r\n"
            .."Host: api.thingspeak.com\r\n"
            .."Connection: keep-alive\r\n"
            .."Accept: */*\r\n"
            .."\r\n");
    end)
    conn:on("disconnection", function(c, error)
        print("error = "..error);
        power_values.inc = power_values.inc + inc_value * MICRO_W;
        write_to_file(FILE_POWER, power_values);
    end)
    conn:connect(80,"api.thingspeak.com");
end;

--каждые 20 секунд отправляем данные на сервер
tmr.alarm(1, 20000, tmr.ALARM_AUTO, send_power_to_server);
